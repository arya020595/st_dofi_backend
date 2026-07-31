module Api
  module V1
    module Admin
      module Manifests
        module CaptureReports
          class FishingGearDetailsController < ApplicationController
            include ::Manifests::FishingGearDetailsReadable
          end
        end
      end
    end
  end
end
