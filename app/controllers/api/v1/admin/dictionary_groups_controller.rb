module Api
  module V1
    module Admin
      class DictionaryGroupsController < ApplicationController
        include RansackSearchable

        before_action :set_dictionary_group, only: %i[show update destroy]

        def index
          authorize DictionaryGroup
          result = apply_ransack_search(policy_scope(DictionaryGroup), default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: DictionaryGroupBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @dictionary_group
          render json: { status: "success", data: DictionaryGroupBlueprint.render_as_hash(@dictionary_group) }
        end

        def create
          authorize DictionaryGroup

          @dictionary_group = DictionaryGroup.new(dictionary_group_params)
          if @dictionary_group.save
            render json: { status: "success", data: DictionaryGroupBlueprint.render_as_hash(@dictionary_group) },
                   status: :created
          else
            render json: { status: "fail", errors: @dictionary_group.errors.full_messages },
                   status: :unprocessable_content
          end
        end

        def update
          authorize @dictionary_group

          if @dictionary_group.update(dictionary_group_params)
            render json: { status: "success", data: DictionaryGroupBlueprint.render_as_hash(@dictionary_group) }
          else
            render json: { status: "fail", errors: @dictionary_group.errors.full_messages },
                   status: :unprocessable_content
          end
        end

        def destroy
          authorize @dictionary_group
          if @dictionary_group.destroy
            render json: { status: "success", message: "Dictionary group removed." }
          else
            render json: { status: "fail", errors: @dictionary_group.errors.full_messages },
                   status: :unprocessable_content
          end
        end

        private

        def set_dictionary_group
          @dictionary_group = DictionaryGroup.find(params.expect(:id))
        end

        def dictionary_group_params
          params.expect(dictionary_group: [:name])
        end
      end
    end
  end
end
