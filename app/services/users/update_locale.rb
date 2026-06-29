module Users
  class UpdateLocale
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(user, locale)
      return Success(user) if user.update(preferred_locale: locale)

      Failure(user)
    end
  end
end
