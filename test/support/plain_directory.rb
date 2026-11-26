# The plaintext counterpart of TlsDirectory: LDAP simple binds straight over TCP, no TLS at all (what AD answers on
# port 389), for AD_TRANSPORT=plain. Same accounts, bind formats and recorded binds/identities as TlsDirectory.
class PlainDirectory < TlsDirectory
  def initialize(**directory)
    super(key: nil, cert: nil, **directory)
  end

  private

  def context(_key, _cert) = nil

  def handle(tcp, behavior)
    answer_bind(tcp) unless behavior == :hang_up
  rescue StandardError
    nil # a TLS client sends a handshake, not an LDAP message: there is nothing to answer
  ensure
    tcp.close
  end
end
