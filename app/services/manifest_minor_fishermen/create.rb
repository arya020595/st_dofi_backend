module ManifestMinorFishermen
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, attributes)
      return Failure(manifest) unless manifest.editable?

      minor = manifest.manifest_minor_fishermen.new(attributes)
      return Failure(minor) unless minor.save

      Success(minor)
    end
  end
end
