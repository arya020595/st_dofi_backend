module Api
  module V1
    module Fisherman
      class DashboardController < ApplicationController
        before_action :authorize_dashboard

        def summary
          data = ::Fisherman::Dashboard::Summary.call(**query_attributes)
          render json: { status: "success", data: DashboardSummaryBlueprint.render_as_hash(data) }
        end

        def top_fishes
          data = ::Fisherman::Dashboard::TopFishesQuery.call(**query_attributes)
          render json: { status: "success", data: DashboardTopFishesBlueprint.render_as_hash(data) }
        end

        def fishing_gear_analytics
          data = ::Fisherman::Dashboard::FishingGearAnalyticsQuery.call(**query_attributes)
          render json: { status: "success", data: DashboardFishingGearAnalyticsBlueprint.render_as_hash(data) }
        end

        def zone_analytics
          data = ::Fisherman::Dashboard::ZoneAnalyticsQuery.call(**query_attributes)
          render json: { status: "success", data: DashboardZoneAnalyticsBlueprint.render_as_hash(data) }
        end

        private

        def authorize_dashboard
          authorize :dashboard, :index?
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
