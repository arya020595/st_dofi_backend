module Api
  module V1
    module Fisherman
      module Manifests
        class MinorFishermenController < ApplicationController
          include ::Manifests::MinorFishermenReadable

          before_action :set_minor_fisherman, only: %i[destroy]

          def create
            authorize ManifestMinorFisherman

            case ManifestMinorFishermen::Create.call(@manifest, minor_fisherman_params)
            in Success(minor)
              render json: { status: "success", data: ManifestMinorFishermanBlueprint.render_as_hash(minor) },
                     status: :created
            in Failure(record)
              render json: { status: "fail", errors: record.errors.full_messages }, status: :unprocessable_content
            end
          end

          def destroy
            authorize @minor_fisherman

            if @manifest.editable? && @minor_fisherman.destroy
              render json: { status: "success", message: "Minor fisherman removed." }
            else
              @minor_fisherman.errors.add(:base, "Manifest is no longer editable") unless @manifest.editable?
              render json: { status: "fail", errors: @minor_fisherman.errors.full_messages },
                     status: :unprocessable_content
            end
          end

          private

          def set_minor_fisherman
            @minor_fisherman = @manifest.manifest_minor_fishermen.find(params.expect(:id))
          end

          def minor_fisherman_params
            params.expect(minor_fisherman: %i[full_name date_of_birth gender relationship_with_owner])
          end
        end
      end
    end
  end
end
