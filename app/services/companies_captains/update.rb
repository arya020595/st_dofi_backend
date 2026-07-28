module CompaniesCaptains
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(captain, attributes)
      return Failure(captain) unless captain.update(attributes)

      captain.revert_to_pending_for_edit!
      Success(captain)
    end
  end
end
