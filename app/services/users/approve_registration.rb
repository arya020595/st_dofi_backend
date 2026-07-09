module Users
  class ApproveRegistration
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(user)
      return Failure(user) unless user.may_approve?

      user.approve!
      Success(user)
    end
  end
end
