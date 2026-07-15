module CompaniesVessels
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(vessel, attributes)
      return Success(vessel) if vessel.update(attributes)

      Failure(vessel)
    end
  end
end
