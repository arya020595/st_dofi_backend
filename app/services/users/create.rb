module Users
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      user = User.new(attributes)
      return Success(user) if user.save

      Failure(user)
    end
  end
end
