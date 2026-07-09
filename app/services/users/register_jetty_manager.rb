module Users
  class RegisterJettyManager
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      user = User.new(attributes.merge(
                        role: jetty_manager_role,
                        password: SecureRandom.base64(24),
                        status: "pending",
                        brunei_id_verified_at: Time.current
                      ))
      return Success(user) if user.save

      Failure(user)
    end

    private

    def jetty_manager_role
      Role.find_by!(reference_id: User::JETTY_MANAGER_ROLE_REFERENCE_ID)
    end
  end
end
