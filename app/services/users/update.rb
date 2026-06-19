module Users
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(user, attributes)
      return Success(user) if user.update(attributes)

      Failure(user)
    end
  end
end
