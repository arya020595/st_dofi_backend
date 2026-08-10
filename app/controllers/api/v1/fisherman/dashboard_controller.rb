module Api
  module V1
    module Fisherman
      class DashboardController < ApplicationController
        before_action :authorize_manifest_access

        def summary
          render json: { status: "success", data: ::Fisherman::Dashboard::Summary.call(**query_attributes) }
        end

        def top_fishes
          render json: { status: "success", data: ::Fisherman::Dashboard::TopFishes.call(**query_attributes) }
        end

        def fishing_gear_analytics
          render json: { status: "success", data: ::Fisherman::Dashboard::FishingGearAnalytics.call(**query_attributes) }
        end

        def zone_analytics
          render json: { status: "success", data: ::Fisherman::Dashboard::ZoneAnalytics.call(**query_attributes) }
        end

        private

        def authorize_manifest_access
          authorize Manifest, :index?
        end

        def query_attributes
          {
            manifest_scope: policy_scope(Manifest),
            start_date: params[:start_date],
            end_date: params[:end_date]
          }
        end
      end
    end
  end
end
