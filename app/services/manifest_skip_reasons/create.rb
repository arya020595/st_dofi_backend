module ManifestSkipReasons
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      reason = ManifestSkipReason.new(attributes)
      return Failure(reason) unless reason.save

      Success(reason)
    end
  end
end
