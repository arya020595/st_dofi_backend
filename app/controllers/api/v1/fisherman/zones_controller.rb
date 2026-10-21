module Api
  module V1
    module Fisherman
      class ZonesController < ApplicationController
        include ::MasterData::ZonesReadable
      end
    end
  end
end
