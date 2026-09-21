module Api
  module V1
    module Admin
      module Manifests
        class MinorFishermenController < ApplicationController
          include ::Manifests::MinorFishermenReadable
        end
      end
    end
  end
end
