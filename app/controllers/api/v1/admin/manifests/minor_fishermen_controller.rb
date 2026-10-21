module Api
  module V1
    module Admin
      module Manifests
        class MinorFishermenController < ApplicationController
          before_action :set_manifest

          def index
            authorize @manifest, policy_class: ManifestApprovalPolicy

            minors = @manifest.manifest_minor_fishermen
            render json: { status: "success", data: ManifestMinorFishermanBlueprint.render_as_hash(minors) }
          end

          private

          def set_manifest
            @manifest = policy_scope(Manifest, policy_scope_class: ManifestApprovalPolicy::Scope)
                        .find(params.expect(:manifest_id))
          end
        end
      end
    end
  end
end
