module Manifests
  module MinorFishermenReadable
    extend ActiveSupport::Concern
    include Manifests::ManifestScoped

    def index
      authorize @manifest
      minors = @manifest.manifest_minor_fishermen
      render json: { status: "success", data: ManifestMinorFishermanBlueprint.render_as_hash(minors) }
    end
  end
end
