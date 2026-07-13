module CompanyProfileContacts
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, attributes)
      contact = company_profile.contacts.new(attributes)
      return Success(contact) if contact.save

      Failure(contact)
    end
  end
end
