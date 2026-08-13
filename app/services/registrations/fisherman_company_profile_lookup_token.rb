module Registrations
  class FishermanCompanyProfileLookupToken
    PURPOSE = "fisherman_company_profile_lookup".freeze
    EXPIRY = 5.minutes

    def self.generate(...) = new.generate(...)
    def self.verify!(...) = new.verify!(...)

    def generate(ic_no)
      verifier.generate(ic_no, expires_in: EXPIRY, purpose: PURPOSE)
    end

    def verify!(token)
      verifier.verify(token, purpose: PURPOSE)
    end

    private

    def verifier
      @verifier ||= Rails.application.message_verifier(PURPOSE)
    end
  end
end
