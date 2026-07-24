module Api
  module V1
    module Approvals
      class ManifestsController < ApplicationController
        include RansackSearchable
        include ManifestApprovalTransitions

        before_action :set_manifest, only: [:show, :update, *ManifestApprovalTransitions::TRANSITION_ACTIONS]

        def index
          authorize Manifest
          result = apply_ransack_search(policy_scope(Manifest), default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: ManifestBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def tab_counts
          authorize Manifest
          render json: { status: "success", data: ::Manifests::TabCounts.call(policy_scope(Manifest)) }
        end

        def show
          authorize @manifest
          render json: { status: "success", data: ManifestDetailBlueprint.render_as_hash(@manifest) }
        end

        def update
          authorize @manifest

          case ::Manifests::Update.call(@manifest, manifest_params)
          in Success(manifest)
            render json: { status: "success", data: ManifestDetailBlueprint.render_as_hash(manifest) }
          in Failure(manifest)
            render json: { status: "fail", errors: manifest.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_manifest
          @manifest = policy_scope(Manifest).find(params.expect(:id))
        end

        def manifest_params
          params.expect(manifest: [:companies_vessel_id, :companies_captain_id,
                                   :port_out_id, :port_out_datetime, :port_out_area,
                                   :port_in_id, :port_in_datetime, :port_in_area,
                                   :zone_id, :zone_area, :longitude, :latitude, :has_minor_fishermen,
                                   { crew_ids: [],
                                     ad_hoc_crew: [%i[crew_name ic_number passport_number
                                                      position nationality date_of_birth]] }])
        end
      end
    end
  end
end
