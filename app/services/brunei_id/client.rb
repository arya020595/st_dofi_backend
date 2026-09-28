module BruneiId
  class Client
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(ic_number:)
      return Failure(:invalid_identity) if ic_number.blank?

      # Mock: no real BruneiID integration exists yet — the faraday/jwt gems and the
      # BRUNEIID_* env vars are reserved for it (see CLAUDE.md, .env.example) but unused
      # today. This mock trusts the FE-supplied ic_number as already verified by BruneiID
      # (Fisherman::ClaimAccount then sets brunei_id_verified_at: Time.current). Callers
      # depend only on the Success/Failure contract, not on how verification happens, so
      # swapping in a real Faraday-based implementation later only requires changing this
      # class's body.
      Success(ic_number)
    end
  end
end
