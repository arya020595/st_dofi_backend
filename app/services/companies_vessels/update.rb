module CompaniesVessels
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(vessel, attributes)
      return Failure(vessel) unless vessel.update(attributes)

      vessel.revert_to_pending_for_edit!
      Success(vessel)
    end
  end
end
