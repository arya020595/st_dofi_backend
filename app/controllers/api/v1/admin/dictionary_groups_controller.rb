module Api
  module V1
    module Admin
      class DictionaryGroupsController < ApplicationController
        include RansackSearchable

        before_action :set_dictionary_group, only: %i[show update destroy]

        def index
          authorize DictionaryGroup
          render_collection(policy_scope(DictionaryGroup), default_sort: "created_at desc")
        end

        def show
          authorize @dictionary_group
          render_resource(@dictionary_group)
        end

        def create
          authorize DictionaryGroup
          create_resource(DictionaryGroup.new(dictionary_group_params))
        end

        def update
          authorize @dictionary_group
          update_resource(@dictionary_group)
        end

        def destroy
          authorize @dictionary_group
          destroy_resource(@dictionary_group, "Dictionary group removed.")
        end

        private

        def set_dictionary_group
          @dictionary_group = DictionaryGroup.find(params.expect(:id))
        end

        def dictionary_group_params
          params.expect(dictionary_group: [:name])
        end

        def render_collection(scope, default_sort:)
          result = apply_ransack_search(scope, default_sort:)
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: DictionaryGroupBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def render_resource(resource, status: :ok)
          render json: { status: "success", data: DictionaryGroupBlueprint.render_as_hash(resource) }, status:
        end

        def create_resource(resource)
          return render_resource(resource, status: :created) if resource.save

          render json: { status: "fail", errors: resource.errors.full_messages }, status: :unprocessable_content
        end

        def update_resource(resource)
          return render_resource(resource) if resource.update(dictionary_group_params)

          render json: { status: "fail", errors: resource.errors.full_messages }, status: :unprocessable_content
        end

        def destroy_resource(resource, message)
          return render json: { status: "success", message: } if resource.destroy

          render json: { status: "fail", errors: resource.errors.full_messages }, status: :unprocessable_content
        end
      end
    end
  end
end
