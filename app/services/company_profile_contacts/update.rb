module CompanyProfileContacts
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(contact, attributes)
      return Success(contact) if contact.update(attributes)

      Failure(contact)
    end
  end
end
