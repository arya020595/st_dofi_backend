require "ipaddr"

module Authentication
  # The one place the Active Directory settings are read from ENV and validated.
  #
  # Staff always authenticate through the directory; AD_MODE only says which one:
  #   mock - local/staging stand-in (MockLdapAuthenticator): every staff user shares AD_MOCK_PASSWORD
  #   ldap - the real directory (LdapAuthenticator), over the transport AD_TRANSPORT names:
  #            ldaps (default) - TLS from the first byte, certificate and host name verified
  #            plain           - no TLS at all: the password crosses the network readable. Only because the client
  #                              chose it (2026-11-26, matching their other AD integrations); never a default, and
  #                              the app warns at boot while it is on
  # DEPLOY_ENV says where the app runs. RAILS_ENV cannot: staging runs with RAILS_ENV=production too. It is set by
  # each deployment's compose file, and mock is refused on production. Every inconsistency raises at boot, so a
  # typo or a missing variable can never leave staff on a weaker path.
  # The constants live in the class body (not a Data.define block, where they would land on Authentication).
  class DirectoryConfig < Data.define(:mode, :deploy_env, :hosts, :port, :netbios_domain, :dns_domain, # rubocop:disable Style/DataInheritance
                                      :bind_format, :ca_file, :connect_timeout, :operation_timeout, :mock_password,
                                      :transport)
    MODES = %w[mock ldap].freeze
    DEPLOY_ENVS = %w[development test staging production].freeze
    BIND_FORMATS = %w[netbios upn].freeze
    TRANSPORTS = %w[ldaps plain].freeze
    PLAINTEXT_LDAP_PORT = 389
    # Ports that only speak TLS: plain LDAP sent there would never get an answer.
    TLS_ONLY_PORTS = [636, 3269].freeze

    class << self
      def current = @current ||= load

      def load(env = ENV, rails_env: Rails.env)
        deploy_env = deploy_env_from(env, rails_env)
        mode = mode_from(env, rails_env, deploy_env)

        new(mode: mode.to_sym, deploy_env: deploy_env, **connection_settings(env),
            **identity_settings(env, default_domain: (User::USERNAME_PREFIX if mode == "mock")),
            mock_password: env["AD_MOCK_PASSWORD"].to_s, transport: transport_from(env))
      end

      private

      def transport_from(env) = env.fetch("AD_TRANSPORT", "ldaps").strip.downcase

      def connection_settings(env)
        { hosts: env["AD_HOST"].to_s.split(",").map(&:strip).compact_blank,
          port: Integer(env.fetch("AD_PORT", "3269"), exception: false),
          ca_file: env["AD_CA_FILE"].to_s.strip.presence,
          connect_timeout: Integer(env.fetch("AD_CONNECT_TIMEOUT", "3"), exception: false),
          operation_timeout: Integer(env.fetch("AD_OPERATION_TIMEOUT", "5"), exception: false) }
      end

      # A production RAILS_ENV must say which deployment it is (staging or production); locally it is RAILS_ENV.
      def deploy_env_from(env, rails_env)
        explicit = env["DEPLOY_ENV"].to_s.strip.downcase.presence
        deploy_env = explicit || (rails_env.to_s == "production" ? nil : rails_env.to_s)
        allowed = rails_env.to_s == "production" ? %w[staging production] : DEPLOY_ENVS
        return deploy_env if allowed.include?(deploy_env)

        raise ArgumentError, "DEPLOY_ENV must be one of: #{allowed.join(', ')} (RAILS_ENV=#{rails_env})"
      end

      def mode_from(env, rails_env, deploy_env)
        mode = env["AD_MODE"].to_s.strip.downcase.presence || (rails_env.to_s == "production" ? nil : "mock")
        raise ArgumentError, "AD_MODE must be one of: #{MODES.join(', ')}" unless MODES.include?(mode)
        if mode == "mock" && deploy_env == "production"
          raise ArgumentError, "AD_MODE=mock is not allowed when DEPLOY_ENV=production"
        end

        mode
      end

      # The mock needs no domain setting: staff usernames are stored as "mprt/<name>", so it defaults to that prefix.
      def identity_settings(env, default_domain:)
        { netbios_domain: env["AD_NETBIOS_DOMAIN"].to_s.strip.presence || default_domain.to_s,
          dns_domain: env["AD_DNS_DOMAIN"].to_s.strip,
          bind_format: env.fetch("AD_BIND_FORMAT", "netbios").strip.downcase }
      end
    end

    def mock? = mode == :mock
    def ldap? = mode == :ldap
    def production? = deploy_env == "production"
    def plain_transport? = ldap? && transport == "plain"

    # Human-readable reasons the current mode cannot work; empty when it is usable. Used by the authenticators to
    # fail closed (503) instead of attempting a half-configured bind.
    def problems
      return ["AD_MOCK_PASSWORD is not set"] if mock? && mock_password.blank?
      return [] unless ldap?

      [*host_problems, *transport_problems, *domain_problems, *tls_problems, *timeout_problems]
    end

    private

    def host_problems
      found = []
      found << "AD_HOST is not set" if hosts.empty?
      found << "AD_HOST must be DNS names covered by the server certificate, not IP addresses" if hosts.any? { ip?(it) }
      found
    end

    # LDAPS never accepts 389, so plaintext can only ever be the explicit AD_TRANSPORT=plain choice.
    def transport_problems
      return ["AD_TRANSPORT must be one of: #{TRANSPORTS.join(', ')}"] unless TRANSPORTS.include?(transport)
      return ["AD_PORT must be a port number"] unless port.is_a?(Integer) && port.between?(1, 65_535)
      return ["AD_PORT #{port} only speaks TLS; plain LDAP uses #{PLAINTEXT_LDAP_PORT}"] if plain_on_tls_port?
      return [] unless transport == "ldaps" && port == PLAINTEXT_LDAP_PORT

      ["AD_PORT must be a valid LDAPS port (not #{PLAINTEXT_LDAP_PORT}; plain LDAP needs AD_TRANSPORT=plain)"]
    end

    def plain_on_tls_port? = transport == "plain" && TLS_ONLY_PORTS.include?(port)

    def domain_problems
      found = []
      found << "AD_BIND_FORMAT must be one of: #{BIND_FORMATS.join(', ')}" unless BIND_FORMATS.include?(bind_format)
      found << "AD_NETBIOS_DOMAIN is not set" if netbios_domain.blank?
      found << "AD_DNS_DOMAIN is not set" if bind_format == "upn" && dns_domain.blank?
      found
    end

    # AD_CA_FILE is optional (unset means the system trust store), but a file that was asked for must work: it is never
    # quietly replaced by the system store. With plain LDAP there is no TLS for it to secure.
    def tls_problems
      return ["AD_CA_FILE has no effect with AD_TRANSPORT=plain; leave it blank"] if ca_file && transport == "plain"
      return [] if ca_file.nil? || certificate_file?

      ["AD_CA_FILE must be a readable PEM file with at least one certificate"]
    end

    # Loads the file the way the TLS connection will, so a missing, unreadable or non-PEM file is reported here.
    def certificate_file?
      OpenSSL::X509::Store.new.add_file(ca_file)
      true
    rescue OpenSSL::X509::StoreError
      false
    end

    def timeout_problems
      return [] if [connect_timeout, operation_timeout].all? { it&.positive? }

      ["AD_CONNECT_TIMEOUT and AD_OPERATION_TIMEOUT must be positive whole seconds"]
    end

    def ip?(host)
      IPAddr.new(host)
      true
    rescue IPAddr::Error
      false
    end
  end
end
