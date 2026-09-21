module Manifests
  module ManifestScoped
    extend ActiveSupport::Concern

    included do
      before_action :set_manifest
    end

    private

    def set_manifest
      @manifest = policy_scope(::Manifest).find(params.expect(:manifest_id))
    end
  end
end
