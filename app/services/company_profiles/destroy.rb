module CompanyProfiles
  class Destroy
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile)
      ActiveRecord::Base.transaction do
        company_profile.contacts.kept.find_each(&:discard!)
        company_profile.discard!
      end

      Success(company_profile)
    rescue Discard::RecordNotDiscarded
      Failure(company_profile)
    end
  end
end
