module Api
  module V1
    module Fisherman
      class ZonesController < ApplicationController
        include ::MasterData::ZonesReadable
        include FishermanReferenceDataAccess
      end
    end
  end
end
