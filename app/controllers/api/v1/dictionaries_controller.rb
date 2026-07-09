module Api
  module V1
    class DictionariesController < ApplicationController
      include RansackSearchable

      DICTIONARY_FIELDS = %i[local_name scientific_name group_name family_name image].freeze

      before_action :set_dictionary, only: %i[show update destroy]

      def index
        authorize Dictionary
        result = apply_ransack_search(policy_scope(Dictionary), default_sort: "created_at desc")
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
          render json: { status: "success", data: DictionaryBlueprint.render_as_hash(result.value!) }, status: :created
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

        if @dictionary.destroy
          render json: { status: "success", message: "Dictionary entry removed." }
        else
          render json: { status: "fail", errors: @dictionary.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def set_dictionary
        @dictionary = Dictionary.find(params.expect(:id))
      end

      # Bulk create: POST multipart with `dictionaries[][local_name]`, `dictionaries[][image]`, etc.
      # Single create: POST multipart/JSON with `dictionary[local_name]`, `dictionary[image]`, etc.
      def entries_params
        if params[:dictionaries].present?
          params.require(:dictionaries).values.map { |entry| entry.permit(*DICTIONARY_FIELDS) }
        else
          [params.expect(dictionary: DICTIONARY_FIELDS)]
        end
      end

      def dictionary_params
        params.expect(dictionary: DICTIONARY_FIELDS)
      end
    end
  end
end
