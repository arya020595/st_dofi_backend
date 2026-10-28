require "test_helper"

# Talks to a real (in-process) TLS server, so it proves what the option-recording tests cannot: that the certificate
# chain and host name are actually enforced, and that a bind over verified TLS works end to end.
class Authentication::LdapAuthenticatorTlsTest < ActiveSupport::TestCase
  include DirectoryTestSupport

  setup do
    @ca_key, @ca = issue_certificate("CN=Test AD CA", authority: true)
    @tmp = Dir.mktmpdir
    @ca_file = write_pem("ca.pem", @ca)
  end

  teardown do
    @server&.close
    @thread&.kill
    FileUtils.remove_entry(@tmp)
  end

  test "binds over TLS when the certificate is signed by the configured CA and names the host" do
    start_directory(dns: "localhost")

    assert_equal Success(:authenticated), authenticator.call(username: "ahmad", password: "right")
    assert_equal Failure(:invalid_credentials), authenticator.call(username: "ahmad", password: "wrong")
  end

  test "refuses a certificate that was not issued by the configured CA" do
    other_ca_file = write_pem("other-ca.pem", issue_certificate("CN=Someone Else", authority: true).last)
    start_directory(dns: "localhost")

    result = authenticator(ca_file: other_ca_file).call(username: "ahmad", password: "right")

    assert_equal Failure(:directory_unavailable), result
  end

  test "refuses a certificate that does not name the host" do
    start_directory(dns: "another-host.example")

    assert_equal Failure(:directory_unavailable), authenticator.call(username: "ahmad", password: "right")
  end

  private

  def authenticator(ca_file: @ca_file)
    config = directory_config(ad_host: "localhost", ad_port: @port.to_s, ad_ca_file: ca_file)
    Authentication::LdapAuthenticator.new(config:, logger: ->(**) {})
  end

  def start_directory(dns:)
    key, cert = issue_certificate("CN=#{dns}", host: dns, issuer: [@ca_key, @ca])
    context = OpenSSL::SSL::SSLContext.new
    context.cert = cert
    context.key = key
    @server = OpenSSL::SSL::SSLServer.new(TCPServer.new("127.0.0.1", 0), context)
    @port = @server.to_io.addr[1]
    @thread = Thread.new { serve_binds }
  end

  def serve_binds
    loop do
      socket = @server.accept
      answer_bind(socket)
    rescue OpenSSL::SSL::SSLError, IOError, SystemCallError
      nil # a client that rejected our certificate hangs up mid-handshake
    ensure
      socket&.close
    end
  end

  # Success for the password "right", invalidCredentials (49) otherwise.
  def answer_bind(socket)
    message_id, (_version, _name, password) = StringIO.new(socket.readpartial(4096)).read_ber(Net::LDAP::AsnSyntax)
    code = password == "right" ? 0 : 49
    socket.write([message_id.to_ber,
                  [code.to_ber_enumerated, "".to_ber, "".to_ber].to_ber_appsequence(1)].to_ber_sequence)
  end

  def issue_certificate(subject, host: nil, authority: false, issuer: nil)
    key = OpenSSL::PKey::EC.generate("prime256v1")
    cert = new_certificate(subject, key, issuer&.last)
    add_extensions(cert, issuer&.last, host:, authority:)
    cert.sign(issuer ? issuer.first : key, OpenSSL::Digest.new("SHA256"))
    [key, cert]
  end

  def new_certificate(subject, key, issuer_cert)
    cert = valid_certificate
    cert.subject = OpenSSL::X509::Name.parse(subject)
    cert.issuer = (issuer_cert || cert).subject
    cert.public_key = key
    cert
  end

  def valid_certificate
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = SecureRandom.random_number(2**32)
    cert.not_before = 1.hour.ago
    cert.not_after = 1.day.from_now
    cert
  end

  def add_extensions(cert, issuer_cert, host:, authority:)
    factory = OpenSSL::X509::ExtensionFactory.new(issuer_cert || cert, cert)
    cert.add_extension(factory.create_extension("basicConstraints", authority ? "CA:TRUE" : "CA:FALSE", true))
    cert.add_extension(factory.create_extension("keyUsage", authority ? "keyCertSign,cRLSign" : "digitalSignature",
                                                true))
    cert.add_extension(factory.create_extension("subjectKeyIdentifier", "hash"))
    cert.add_extension(factory.create_extension("subjectAltName", "DNS:#{host}")) if host
  end

  def write_pem(name, cert)
    path = File.join(@tmp, name)
    File.write(path, cert.to_pem)
    path
  end
end
