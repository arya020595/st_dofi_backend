module Fisherman
  class CheckIcAvailability
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(normalized_ic_number:, company_profile:)
      existing_user = User.kept.find_by(normalized_ic_number: normalized_ic_number)
      status = if existing_user.nil?
                 :available
               elsif existing_user.company_profile_id == company_profile.id
                 :existing_same_company
               else
                 :existing_other_company
               end

      Success(status: status, existing_user: existing_user)
    end
  end
end
