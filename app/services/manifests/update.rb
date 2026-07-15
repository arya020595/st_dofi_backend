module Manifests
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, attributes)
      return Failure(manifest) unless manifest.editable?

      ActiveRecord::Base.transaction do
        manifest.update!(attributes.except(:crew_ids, :ad_hoc_crew))
        if attributes.key?(:crew_ids) || attributes.key?(:ad_hoc_crew)
          SetCrew.call(manifest, crew_ids: attributes[:crew_ids], ad_hoc_crew: attributes[:ad_hoc_crew])
        end
      end
      Success(manifest)
    rescue ActiveRecord::RecordInvalid
      Failure(manifest)
    end
  end
end
