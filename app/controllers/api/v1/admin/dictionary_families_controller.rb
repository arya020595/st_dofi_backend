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
          render_resource(@dictionary_family)
        end

        def create
          authorize DictionaryFamily
          persist(DictionaryFamily.new(dictionary_family_params), :save)
        end

        def update
          authorize @dictionary_family
          persist(@dictionary_family, :update)
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

        def persist(resource, operation)
          successful = operation == :save ? resource.save : resource.update(dictionary_family_params)
          return render_resource(resource) if successful

          render json: { status: "fail", errors: resource.errors.full_messages }, status: :unprocessable_content
        end

        def render_resource(resource)
          render json: { status: "success", data: DictionaryFamilyBlueprint.render_as_hash(resource) },
                 status: action_name == "create" ? :created : :ok
        end
      end
    end
  end
end
