module BruneiId
  class Client
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(ic_number:)
      return Failure(:invalid_identity) if ic_number.blank?

      # Mock: no real BruneiID integration exists yet — the faraday/jwt gems and the
      # BRUNEIID_* env vars are reserved for it (see CLAUDE.md, .env.example) but unused
      # today. This mock accepts the FE-supplied IC as pre-verified by BruneiID. Provisioning and
      # the real callback record the verification timestamp before issuing an application token.
      # to login. Callers depend only on the Success/Failure contract, not on how
      # verification happens, so swapping in a real Faraday-based implementation later
      # only requires changing this class's body.
      Success(ic_number)
    end
  end
end
