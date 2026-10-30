module Api
  module V1
    module Admin
      class DictionariesController < ApplicationController
        include RansackSearchable

        DICTIONARY_FIELDS = %i[local_name scientific_name dictionary_group_id dictionary_family_id image].freeze

        before_action :set_dictionary, only: %i[show update destroy]

        def index
          authorize Dictionary
          result = apply_ransack_search(
            policy_scope(Dictionary).includes(:dictionary_group, :dictionary_family).with_attached_image,
            default_sort: "created_at desc"
          )
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: DictionaryBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @dictionary
          render json: { status: "success", data: DictionaryBlueprint.render_as_hash(@dictionary) }
        end

        def create
          authorize Dictionary

          result = Dictionaries::Create.call(entries_params)
          if result.success?
            render json: { status: "success", data: DictionaryBlueprint.render_as_hash(result.value!) },
                   status: :created
          else
            render json: { status: "fail", errors: result.failure.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @dictionary

          case Dictionaries::Update.call(@dictionary, dictionary_params)
          in Success(dictionary)
            render json: { status: "success", data: DictionaryBlueprint.render_as_hash(dictionary) }
          in Failure(dictionary)
            render json: { status: "fail", errors: dictionary.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @dictionary

          if @dictionary.discard
            render json: { status: "success", message: "Dictionary entry removed." }
          else
            render json: { status: "fail", errors: @dictionary.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_dictionary
          @dictionary = policy_scope(Dictionary).find(params.expect(:id))
        end

        # Bulk create: POST multipart with `dictionaries[][local_name]`, `dictionaries[][image]`, etc.
        # Single create: POST multipart/JSON with `dictionary[local_name]`, `dictionary[image]`, etc.
        def entries_params
          if params[:dictionaries].present?
            bulk_entries.map { |entry| entry.permit(*DICTIONARY_FIELDS) }
          else
            [params.expect(dictionary: DICTIONARY_FIELDS)]
          end
        end

        # `dictionaries[][local_name]` arrives as an Array of entries, `dictionaries[0][local_name]` as a Hash keyed
        # by index; both are the same bulk request.
        def bulk_entries
          entries = params.require(:dictionaries)
          entries.is_a?(Array) ? entries : entries.values
        end

        def dictionary_params
          params.expect(dictionary: DICTIONARY_FIELDS)
        end
      end
    end
  end
end
