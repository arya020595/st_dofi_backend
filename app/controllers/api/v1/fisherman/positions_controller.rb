module Api
  module V1
    module Fisherman
      class PositionsController < ApplicationController
        include ::MasterData::PositionsReadable
      end
    end
  end
end
