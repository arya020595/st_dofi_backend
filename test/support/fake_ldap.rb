# Stands in for Net::LDAP in LdapAuthenticator tests. `FakeLdap.answering(outcome)` returns a fresh class that
# records how it was built (`.built`) and answers each bind from `outcome`, called with the constructor options:
# :bound for success, an LDAP result code for a refusal, or an exception to raise.
class FakeLdap
  RIGHT_PASSWORD = "right".freeze
  DEFAULT_OUTCOME = ->(options) { options.dig(:auth, :password) == RIGHT_PASSWORD ? :bound : 49 }

  def self.answering(outcome = DEFAULT_OUTCOME)
    Class.new(self) do
      define_singleton_method(:built) { @built ||= [] }
      define_singleton_method(:outcome) { outcome }
    end
  end

  def initialize(**options)
    @options = options
    self.class.built << options
  end

  def bind # rubocop:disable Naming/PredicateMethod -- mirrors Net::LDAP#bind
    result = self.class.outcome.call(@options)
    raise result if result.is_a?(Exception)

    @code = result unless result == :bound
    result == :bound
  end

  def get_operation_result # rubocop:disable Naming/AccessorMethodName -- mirrors Net::LDAP
    Struct.new(:code).new(@code)
  end
end
