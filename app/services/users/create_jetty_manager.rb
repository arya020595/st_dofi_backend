module Users
  # Jetty Managers are created only by a DoFi Officer (User Management → External Users). The officer
  # is the vetting step, so the account starts active and the Jetty Manager can log in via BruneiID
  # straight away; created_by records who provisioned it.
  class CreateJettyManager
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes, actor:)
      user = User.new(attributes.merge(role: jetty_manager_role, status: "active", created_by: actor,
                                       password: SecureRandom.base64(24)))
      return Success(user) if user.save

      Failure(user)
    rescue ActiveRecord::RecordNotUnique
      # A concurrent request claimed the same IC between validation and insert — the kept-row unique
      # index is the final authority, so report it as the same validation error instead of a 500.
      user.errors.add(:normalized_ic_number, :taken)
      Failure(user)
    end

    private

    def jetty_manager_role
      Role.find_by!(kind: Role::JETTY_MANAGER)
    end
  end
end
