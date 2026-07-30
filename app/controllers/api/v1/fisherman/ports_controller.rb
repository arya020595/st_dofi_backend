module Api
  module V1
    module Fisherman
      class PortsController < ApplicationController
        include ::MasterData::PortsReadable

        private

        def ports_default_sort
          "port_name asc"
        end
      end
    end
  end
end
