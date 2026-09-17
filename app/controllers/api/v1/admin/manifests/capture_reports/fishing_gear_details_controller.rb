module Api
  module V1
    module Admin
      module Manifests
        module CaptureReports
          class FishingGearDetailsController < ApplicationController
            include ::Manifests::FishingGearDetailsReadable

            private

            def capture_report_policy_class = CaptureReportVerificationPolicy
          end
        end
      end
    end
  end
end
