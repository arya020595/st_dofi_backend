module Api
  module V1
    module Admin
      module Manifests
        module CaptureReports
          class FishCaptureDetailsController < ApplicationController
            include ::Manifests::FishCaptureDetailsReadable
          end
        end
      end
    end
  end
end
