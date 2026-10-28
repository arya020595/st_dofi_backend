# A stand-in Active Directory for the tests: a real TCP + TLS server on 127.0.0.1 (a port the OS picks) that answers
# LDAP simple binds. It checks nothing but what the authentication code sends over the wire, so it proves our side of
# the protocol and nothing about the client's real directory. Temporary certificates only; never part of the app.
#
#   accounts:      { "ahmad" => "secret", "gone" => { password: "secret", enabled: false } } - who may bind. Without it
#                  any name binds with the password "right" (enough for the plain TLS tests).
#   bind_formats:  which identities it understands: "MPRT\name" (:netbios) and/or "name@MPRT.EG.GOV.BN" (:upn)
#   script:        one entry per connection, in order, then :serve for the rest:
#                    :serve              handshake with `cert`, answer the bind (default)
#                    :wrong_certificate  handshake with `rejected_cert` instead
#                    :hang_up            close the TCP connection straight away
#                    :silent             complete the handshake, read the bind, never answer
#
# `accepted` counts TCP connections, `binds` the passwords asked for and `identities` the names they were asked for.
class TlsDirectory
  NETBIOS_IDENTITY = /\A(?<domain>[^\\@]+)\\(?<name>[^\\@]+)\z/
  UPN_IDENTITY = /\A(?<name>[^\\@]+)@(?<domain>[^\\@]+)\z/

  attr_reader :port, :accepted, :binds, :identities

  def initialize(key:, cert:, script: [], rejected: nil, **directory)
    @contexts = { serve: context(key, cert), wrong_certificate: (context(*rejected) if rejected) }
    @script = script.dup
    @accepted = 0
    @binds = []
    @identities = []
    @lock = Mutex.new
    @connections = []
    describe_directory(**directory)
    listen
  end

  def close
    @server.close
    @thread.kill
    @lock.synchronize { @connections.each(&:kill) }
  end

  private

  def describe_directory(accounts: nil, bind_formats: %i[netbios upn], netbios_domain: "MPRT",
                         dns_domain: "MPRT.EG.GOV.BN")
    @accounts = accounts&.to_h do |name, account|
      [name.downcase, account.is_a?(Hash) ? account : { password: account }]
    end
    @formats = { netbios: [NETBIOS_IDENTITY, netbios_domain], upn: [UPN_IDENTITY, dns_domain] }.slice(*bind_formats)
  end

  def listen
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @thread = Thread.new { accept_connections }
  end

  def context(key, cert)
    OpenSSL::SSL::SSLContext.new.tap do |context|
      context.cert = cert
      context.key = key
    end
  end

  def accept_connections
    loop do
      tcp = @server.accept
      @lock.synchronize do
        @accepted += 1
        behavior = @script.shift || :serve
        @connections << Thread.new { handle(tcp, behavior) }
      end
    end
  rescue IOError, SystemCallError
    nil # the server was closed
  end

  def handle(tcp, behavior)
    return tcp.close if behavior == :hang_up

    socket = OpenSSL::SSL::SSLSocket.new(tcp, @contexts.fetch(behavior == :silent ? :serve : behavior))
    socket.sync_close = true
    socket.accept
    behavior == :silent ? socket.readpartial(4096) && sleep : answer_bind(socket)
  rescue OpenSSL::SSL::SSLError, IOError, SystemCallError
    nil # a client that rejected our certificate hangs up mid-handshake
  ensure
    socket ? socket.close : tcp.close
  end

  def answer_bind(socket)
    message_id, (_version, identity, password) = StringIO.new(socket.readpartial(4096)).read_ber(Net::LDAP::AsnSyntax)
    @lock.synchronize do
      @binds << password
      @identities << identity
    end
    socket.write([message_id.to_ber,
                  [result_code(identity, password).to_ber_enumerated, "".to_ber, "".to_ber].to_ber_appsequence(1)]
                  .to_ber_sequence)
  end

  # 0 for success, 49 (invalidCredentials) for everything else: AD says the same for a wrong password and for a
  # disabled or locked account.
  def result_code(identity, password)
    return password == "right" ? 0 : 49 unless @accounts

    account = @accounts[account_name(identity)]
    return 49 unless account&.fetch(:enabled, true)

    account[:password] == password ? 0 : 49
  end

  def account_name(identity)
    @formats.each_value do |(pattern, domain)|
      match = pattern.match(identity.to_s)
      return match[:name].downcase if match && match[:domain].casecmp?(domain)
    end
    nil
  end
end
