require "net/ldap"

module Authentication
  # Checks one password against Active Directory over LDAPS. All the LDAP networking lives here (TLS, timeouts,
  # host failover, bind), and nothing else: it knows nothing about users, roles or DoFi accounts.
  #
  # Contract (shared with MockLdapAuthenticator): call(username:, password:) returns
  #   Success(:authenticated)
  #   Failure(:invalid_credentials)   - AD said no (wrong password, unknown/disabled/locked/expired account)
  #   Failure(:directory_unavailable) - AD could not be asked (misconfiguration, network, TLS, timeout)
  # `username` is the short AD name; the bind identity is built from it and the configured format.
  #
  # net-ldap fails over to the next host only when it cannot connect or complete TLS, never after AD rejected the
  # credentials, so a wrong password is not replayed across every domain controller (which would multiply AD's
  # lockout counter). It does not verify certificates unless told to, hence the explicit TLS options below.
  class LdapAuthenticator
    include Dry::Monads[:result]

    MAX_PASSWORD_LENGTH = 256
    UNAVAILABLE_ERRORS = [Net::LDAP::Error, OpenSSL::SSL::SSLError, SystemCallError, SocketError, IOError,
                          Timeout::Error].freeze
    # Why a certificate was refused, as a fixed vocabulary (first match wins, most specific first): the OpenSSL text is
    # matched, never logged, because it also carries the peer address and certificate details. net-ldap hides a TLS
    # failure inside its own error classes, so the match is on the message, which lists every host's failure when
    # several were tried.
    TLS_FAILURES = {
      /certificate has expired/ => "certificate_expired",
      /not yet valid/ => "certificate_not_yet_valid",
      /hostname mismatch|does not match the server certificate/ => "hostname_mismatch",
      /unable to get (local )?issuer certificate|self[- ]signed certificate|unable to verify the first certificate/ =>
        "untrusted_certificate",
      /certificate verify failed/ => "certificate_rejected"
    }.freeze

    def self.call(...) = new.call(...)

    def initialize(config: DirectoryConfig.current, ldap_class: Net::LDAP, logger: ApplicationLogger)
      @config = config
      @ldap_class = ldap_class
      @logger = logger
    end

    def call(username:, password:)
      return Failure(:invalid_credentials) unless usable?(username, password)
      return unavailable("misconfigured", problems: config.problems) if config.problems.any?

      bind(username, password)
    rescue *UNAVAILABLE_ERRORS => e
      unavailable(e.class.name, tls: tls_failure(e))
    end

    private

    attr_reader :config, :ldap_class, :logger

    # A blank password must never reach the server: an LDAP simple bind with an empty password is an
    # unauthenticated bind, which many servers answer with success.
    def usable?(username, password)
      DirectoryUsername::SHORT_NAME.match?(username.to_s) && password.is_a?(String) && password.present? &&
        password.length <= MAX_PASSWORD_LENGTH && password.exclude?("\0")
    end

    def bind(username, password)
      ldap = build_ldap(bind_identity(username), password)
      return Success(:authenticated) if Timeout.timeout(total_timeout) { ldap.bind }

      code = ldap.get_operation_result&.code
      return Failure(:invalid_credentials) if code == Net::LDAP::ResultCodeInvalidCredentials

      unavailable("result_code_#{code}")
    end

    def build_ldap(identity, password)
      ldap_class.new(hosts: config.hosts.map { [it, config.port] }, connect_timeout: config.connect_timeout,
                     encryption: { method: :simple_tls, tls_options: tls_options },
                     auth: { method: :simple, username: identity, password: password })
    end

    def bind_identity(username)
      config.bind_format == "upn" ? "#{username}@#{config.dns_domain}" : "#{config.netbios_domain}\\#{username}"
    end

    # Verifies the server certificate chain and, through net-ldap, that its name matches the host we dialled.
    def tls_options
      options = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS.merge(verify_mode: OpenSSL::SSL::VERIFY_PEER,
                                                               min_version: OpenSSL::SSL::TLS1_2_VERSION)
      config.ca_file ? options.merge(ca_file: config.ca_file) : options
    end

    # net-ldap only times out the connection and TLS handshake, so the wait for the bind answer is bounded here.
    def total_timeout = (config.connect_timeout * config.hosts.size) + config.operation_timeout

    def tls_failure(error)
      message = error.message.to_s
      TLS_FAILURES.find { |pattern, _category| message.match?(pattern) }&.last
    end

    def unavailable(reason, **details)
      logger.call(event: "ad.directory_unavailable", level: :error, params: { reason:, **details.compact })
      Failure(:directory_unavailable)
    end
  end
end
