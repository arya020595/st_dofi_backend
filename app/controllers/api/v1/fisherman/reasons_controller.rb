module Api
  module V1
    module Fisherman
      class ReasonsController < ApplicationController
        include ::MasterData::ReasonsReadable
      end
    end
  end
end
