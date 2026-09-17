module Api
  module V1
    module Fisherman
      class NationalitiesController < ApplicationController
        include ::MasterData::NationalitiesReadable
        include FishermanReferenceDataAccess
      end
    end
  end
end
