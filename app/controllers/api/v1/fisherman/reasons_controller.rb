module Api
  module V1
    module Fisherman
      class ReasonsController < ApplicationController
        include ::MasterData::ReasonsReadable
        include FishermanReferenceDataAccess
      end
    end
  end
end
