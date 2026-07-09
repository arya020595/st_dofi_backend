module Api
  module V1
    module MasterData
      class ReasonsController < ApplicationController
        include RansackSearchable

        before_action :set_reason, only: %i[show update destroy]

        def index
          authorize ManifestSkipReason
          result = apply_ransack_search(policy_scope(ManifestSkipReason), default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: ManifestSkipReasonBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @reason
          render json: { status: "success", data: ManifestSkipReasonBlueprint.render_as_hash(@reason) }
        end

        def create
          authorize ManifestSkipReason

          case ManifestSkipReasons::Create.call(reason_params)
          in Success(reason)
            render json: { status: "success", data: ManifestSkipReasonBlueprint.render_as_hash(reason) },
                   status: :created
          in Failure(reason)
            render json: { status: "fail", errors: reason.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @reason

          case ManifestSkipReasons::Update.call(@reason, reason_params)
          in Success(reason)
            render json: { status: "success", data: ManifestSkipReasonBlueprint.render_as_hash(reason) }
          in Failure(reason)
            render json: { status: "fail", errors: reason.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @reason

          if @reason.discard
            render json: { status: "success", message: "Reason removed." }
          else
            render json: { status: "fail", errors: @reason.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_reason
          @reason = ManifestSkipReason.find(params.expect(:id))
        end

        def reason_params
          params.expect(reason: %i[name])
        end
      end
    end
  end
end
