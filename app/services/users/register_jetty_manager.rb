module Users
  class RegisterJettyManager
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      user = rejected_user(attributes[:ic_number]) || User.new
      user.assign_attributes(build_attributes(attributes, user: user))
      return Success(user) if user.save

      Failure(user)
    end

    private

    def build_attributes(attributes, user:)
      base = attributes.merge(status: "pending", brunei_id_verified_at: Time.current, rejection_reason: nil)
      base[:role] ||= jetty_manager_role if user.new_record?
      base[:password] ||= SecureRandom.base64(24) if user.new_record?
      base
    end

    def rejected_user(ic_number)
      User.kept.find_by(normalized_ic_number: IcNumbers::Normalize.call(ic_number),
                        status: "rejected", role: jetty_manager_role)
    end

    def jetty_manager_role
      Role.find_by!(kind: Role::JETTY_MANAGER)
    end
  end
end
