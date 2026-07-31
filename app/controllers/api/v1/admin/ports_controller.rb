module Api
  module V1
    module Admin
      class PortsController < ApplicationController
        include ::MasterData::PortsReadable

        def create
          authorize Port

          case Ports::Create.call(port_params)
          in Success(port)
            render json: { status: "success", data: PortBlueprint.render_as_hash(port) }, status: :created
          in Failure(port)
            render json: { status: "fail", errors: port.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          set_port
          authorize @port

          case Ports::Update.call(@port, port_params)
          in Success(port)
            render json: { status: "success", data: PortBlueprint.render_as_hash(port) }
          in Failure(port)
            render json: { status: "fail", errors: port.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          set_port
          authorize @port

          if @port.destroy
            render json: { status: "success", message: "Port removed." }
          else
            render json: { status: "fail", errors: @port.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def port_params
          params.expect(port: %i[port_name latitude longitude])
        end
      end
    end
  end
end
