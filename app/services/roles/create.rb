module Roles
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes, permission_codes: nil)
      role = Role.new(attributes)
      return Failure(role) unless role.save

      role.permissions = Permission.where(code: permission_codes) if permission_codes
      Success(role)
    end
  end
end
