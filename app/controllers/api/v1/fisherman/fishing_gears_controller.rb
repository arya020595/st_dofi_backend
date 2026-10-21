module Api
  module V1
    module Fisherman
      class FishingGearsController < ApplicationController
        include ::MasterData::FishingGearsReadable
      end
    end
  end
end
