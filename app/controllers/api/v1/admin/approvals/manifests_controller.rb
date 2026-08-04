module Api
  module V1
    module Admin
      module Approvals
        class ManifestsController < ApplicationController
          include RansackSearchable
          include ManifestApprovalTransitions

          before_action :set_manifest,
                        only: [:show, :update, :port_out_approval, :port_in_approval,
                               *ManifestApprovalTransitions::TRANSITION_ACTIONS]

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

          def port_out_approval
            authorize @manifest, :show?
            render_approval_histories("port_out_status")
          end

          def port_in_approval
            authorize @manifest, :show?
            render_approval_histories("port_in_status")
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

          def render_approval_histories(status_type)
            render json: {
              status: "success",
              data: {
                manifest_id: @manifest.id,
                status_type: status_type,
                current_status: current_status_for(status_type),
                histories: approval_histories_for(status_type).map { |history| approval_history_payload(history) }
              }
            }
          end

          def current_status_for(status_type)
            case status_type
            when "port_out_status" then @manifest.port_out_status
            when "port_in_status" then @manifest.port_in_status
            end
          end

          def approval_history_payload(history)
            history.slice("id", "action", "status_type", "from_state", "to_state", "remarks", "changed_by_id",
                          "created_at")
                   .symbolize_keys
                   .merge(changed_by: approval_history_actor_payload(history.changed_by))
          end

          def approval_history_actor_payload(user)
            return nil unless user

            {
              id: user.id,
              name: user.name,
              email: user.email,
              username: user.username,
              unit: user.unit,
              position: user.position
            }
          end

          def approval_histories_for(status_type)
            @manifest.manifest_histories
                     .includes(:changed_by)
                     .where(status_type: status_type, to_state: "approved")
                     .order(created_at: :desc)
          end
        end
      end
    end
  end
end
