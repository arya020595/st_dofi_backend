module Api
  module V1
    module Fisherman
      class DictionaryFamiliesController < ApplicationController
        include RansackSearchable

        def index
          result = apply_ransack_search(DictionaryFamily.includes(:dictionary_group),
                                        default_sort: "name asc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: DictionaryFamilyBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end
      end
    end
  end
end
