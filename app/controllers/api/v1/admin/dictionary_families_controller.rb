module Api
  module V1
    module Admin
      class DictionaryFamiliesController < ApplicationController
        include RansackSearchable

        before_action :set_dictionary_family, only: %i[show update destroy]

        def index
          authorize DictionaryFamily
          result = apply_ransack_search(policy_scope(DictionaryFamily).includes(:dictionary_group),
                                        default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: DictionaryFamilyBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @dictionary_family
          render json: { status: "success", data: DictionaryFamilyBlueprint.render_as_hash(@dictionary_family) }
        end

        def create
          authorize DictionaryFamily

          @dictionary_family = DictionaryFamily.new(dictionary_family_params)
          if @dictionary_family.save
            render json: { status: "success", data: DictionaryFamilyBlueprint.render_as_hash(@dictionary_family) },
                   status: :created
          else
            render json: { status: "fail", errors: @dictionary_family.errors.full_messages },
                   status: :unprocessable_content
          end
        end

        def update
          authorize @dictionary_family

          if @dictionary_family.update(dictionary_family_params)
            render json: { status: "success", data: DictionaryFamilyBlueprint.render_as_hash(@dictionary_family) }
          else
            render json: { status: "fail", errors: @dictionary_family.errors.full_messages },
                   status: :unprocessable_content
          end
        end

        def destroy
          authorize @dictionary_family
          if @dictionary_family.destroy
            render json: { status: "success", message: "Dictionary family removed." }
          else
            render json: { status: "fail", errors: @dictionary_family.errors.full_messages },
                   status: :unprocessable_content
          end
        end

        private

        def set_dictionary_family
          @dictionary_family = DictionaryFamily.find(params.expect(:id))
        end

        def dictionary_family_params
          params.expect(dictionary_family: %i[name dictionary_group_id])
        end
      end
    end
  end
end
