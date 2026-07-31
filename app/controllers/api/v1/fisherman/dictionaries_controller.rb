module Api
  module V1
    module Fisherman
      class DictionariesController < ApplicationController
        include RansackSearchable

        def index
          authorize Manifest, :create?
          result = apply_ransack_search(policy_scope(Dictionary), default_sort: "local_name asc")
          pagy, records = pagy(:offset, result)

          render json: { status: "success", data: DictionaryBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end
      end
    end
  end
end
