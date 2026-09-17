module Api
  module V1
    module Fisherman
      class PositionsController < ApplicationController
        include ::MasterData::PositionsReadable
        include FishermanReferenceDataAccess
      end
    end
  end
end
