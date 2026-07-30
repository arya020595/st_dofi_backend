module Manifests
  module MinorFishermenReadable
    extend ActiveSupport::Concern
    include Manifests::ManifestScoped

    def index
      authorize ManifestMinorFisherman
      minors = policy_scope(ManifestMinorFisherman).where(manifest: @manifest)
      render json: { status: "success", data: ManifestMinorFishermanBlueprint.render_as_hash(minors) }
    end
  end
end
