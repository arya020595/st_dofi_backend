module Manifests
  module ManifestScoped
    extend ActiveSupport::Concern

    included do
      before_action :set_manifest
    end

    private

    def set_manifest
      scope = policy_scope(::Manifest, policy_scope_class: manifest_policy_scope_class)
      @manifest = scope.find(params.expect(:manifest_id))
    end

    def manifest_policy_scope_class = ManifestPolicy::Scope
  end
end
