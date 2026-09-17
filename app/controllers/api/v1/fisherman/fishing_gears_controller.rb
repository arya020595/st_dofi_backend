module Api
  module V1
    module Fisherman
      class FishingGearsController < ApplicationController
        include ::MasterData::FishingGearsReadable
        include FishermanReferenceDataAccess
      end
    end
  end
end
