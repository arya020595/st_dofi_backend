module Roles
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(role, attributes, permission_codes: nil)
      role.assign_attributes(attributes)
      return Failure(role) unless role.save

      role.permissions = Permission.where(code: permission_codes) if permission_codes
      Success(role)
    end
  end
end
