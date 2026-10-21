module Api
  module V1
    module Fisherman
      class NationalitiesController < ApplicationController
        include ::MasterData::NationalitiesReadable
      end
    end
  end
end
