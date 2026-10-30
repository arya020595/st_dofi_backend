# Throwaway certificates for the TLS tests: a CA, and server certificates it issues. Nothing here is a real secret.
module TestCertificates
  # Returns [key, certificate]. `issuer` is a [key, certificate] pair from an earlier call (a self-signed
  # certificate when omitted); `expired` backdates the validity window.
  def issue_certificate(subject, host: nil, authority: false, issuer: nil, expired: false)
    key = OpenSSL::PKey::EC.generate("prime256v1")
    cert = new_certificate(subject, key, issuer&.last, expired:)
    add_extensions(cert, issuer&.last, host:, authority:)
    cert.sign(issuer ? issuer.first : key, OpenSSL::Digest.new("SHA256"))
    [key, cert]
  end

  def write_pem(dir, name, cert)
    path = File.join(dir, name)
    File.write(path, cert.to_pem)
    path
  end

  private

  def new_certificate(subject, key, issuer_cert, expired:)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = SecureRandom.random_number(2**32)
    cert.not_before, cert.not_after = validity(expired)
    cert.subject = OpenSSL::X509::Name.parse(subject)
    cert.issuer = (issuer_cert || cert).subject
    cert.public_key = key
    cert
  end

  def validity(expired) = expired ? [2.days.ago, 1.day.ago] : [1.hour.ago, 1.day.from_now]

  def add_extensions(cert, issuer_cert, host:, authority:)
    factory = OpenSSL::X509::ExtensionFactory.new(issuer_cert || cert, cert)
    cert.add_extension(factory.create_extension("basicConstraints", authority ? "CA:TRUE" : "CA:FALSE", true))
    cert.add_extension(factory.create_extension("keyUsage", authority ? "keyCertSign,cRLSign" : "digitalSignature",
                                                true))
    cert.add_extension(factory.create_extension("subjectKeyIdentifier", "hash"))
    cert.add_extension(factory.create_extension("subjectAltName", "DNS:#{host}")) if host
  end
end
