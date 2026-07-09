module Api
  module V1
    module MasterData
      class NationalitiesController < ApplicationController
        include RansackSearchable

        before_action :set_nationality, only: %i[show update destroy]

        def index
          authorize Nationality
          result = apply_ransack_search(policy_scope(Nationality), default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: NationalityBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @nationality
          render json: { status: "success", data: NationalityBlueprint.render_as_hash(@nationality) }
        end

        def create
          authorize Nationality

          case Nationalities::Create.call(nationality_params)
          in Success(nationality)
            render json: { status: "success", data: NationalityBlueprint.render_as_hash(nationality) },
                   status: :created
          in Failure(nationality)
            render json: { status: "fail", errors: nationality.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @nationality

          case Nationalities::Update.call(@nationality, nationality_params)
          in Success(nationality)
            render json: { status: "success", data: NationalityBlueprint.render_as_hash(nationality) }
          in Failure(nationality)
            render json: { status: "fail", errors: nationality.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @nationality

          if @nationality.destroy
            render json: { status: "success", message: "Nationality removed." }
          else
            render json: { status: "fail", errors: @nationality.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_nationality
          @nationality = Nationality.find(params.expect(:id))
        end

        def nationality_params
          params.expect(nationality: %i[name code])
        end
      end
    end
  end
end
