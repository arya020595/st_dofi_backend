module Api
  module V1
    module Fisherman
      class DictionaryGroupsController < ApplicationController
        include RansackSearchable

        def index
          authorize DictionaryGroup
          result = apply_ransack_search(policy_scope(DictionaryGroup), default_sort: "name asc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: DictionaryGroupBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end
      end
    end
  end
end
