module Api
  module V1
    module MasterData
      class PortsController < ApplicationController
        include RansackSearchable

        before_action :set_port, only: %i[show update destroy]

        def index
          authorize Port
          result = apply_ransack_search(policy_scope(Port), default_sort: "reference_id asc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: PortBlueprint.render_as_hash(records), meta: pagination_meta(pagy) }
        end

        def show
          authorize @port
          render json: { status: "success", data: PortBlueprint.render_as_hash(@port) }
        end

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
          authorize @port

          case Ports::Update.call(@port, port_params)
          in Success(port)
            render json: { status: "success", data: PortBlueprint.render_as_hash(port) }
          in Failure(port)
            render json: { status: "fail", errors: port.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @port

          if @port.destroy
            render json: { status: "success", message: "Port removed." }
          else
            render json: { status: "fail", errors: @port.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_port
          @port = Port.find(params.expect(:id))
        end

        def port_params
          params.expect(port: %i[port_name latitude longitude])
        end
      end
    end
  end
end
