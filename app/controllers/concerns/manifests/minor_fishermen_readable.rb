module Manifests
  module MinorFishermenReadable
    extend ActiveSupport::Concern
    include Manifests::ManifestScoped

    def index
      authorize @manifest, policy_class: manifest_policy_class
      minors = @manifest.manifest_minor_fishermen
      render json: { status: "success", data: ManifestMinorFishermanBlueprint.render_as_hash(minors) }
    end

    private

    def manifest_policy_class = ManifestPolicy
  end
end
