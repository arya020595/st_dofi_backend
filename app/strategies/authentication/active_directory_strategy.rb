module Authentication
  # Warden's side of staff sign-in: take the username/password Devise already parsed, hand them to OfficerLogin and
  # translate the answer. Registered in config/initializers/directory_authentication.rb and placed ahead of
  # database_authenticatable, so for staff the directory decides and the local password is never consulted.
  class ActiveDirectoryStrategy < Devise::Strategies::Authenticatable
    include Dry::Monads[:result]

    def authenticate!
      return fail!(:invalid) if null_byte?

      case OfficerLogin.call(username: authentication_hash[:username], password:)
      in Success(user) then success!(user)
      in Failure(:not_applicable) then pass
      in Failure(:directory_unavailable) then custom!(unavailable_response)
      in Failure(_) then fail!(:invalid)
      end
    end

    private

    # No account can have a NUL in its username or password, and PostgreSQL and bcrypt raise on one (a 500) when
    # Devise's own lookup and password check run after this strategy passes, so it is refused here for every sign-in.
    def null_byte? = [authentication_hash[:username], password].any? { it.to_s.include?("\0") }

    def unavailable_response
      body = { status: "fail", message: I18n.t("errors.directory_unavailable") }.to_json
      [503, { "Content-Type" => "application/json" }, [body]]
    end
  end
end
