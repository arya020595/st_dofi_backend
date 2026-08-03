require "test_helper"

module Api
  module V1
    module Admin
      class PortsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @headers = officer_headers_for(permission_codes: %w[ports.view ports.list ports.create ports.update
                                                              ports.delete])
          @port = create(:port)
        end

        test "index lists ports" do
          get "/api/v1/admin/master_data/ports", headers: @headers

          assert_response :ok
          assert_includes response.parsed_body["data"].pluck("id"), @port.id
        end

        test "show returns the port" do
          get "/api/v1/admin/master_data/ports/#{@port.id}", headers: @headers

          assert_response :ok
          assert_equal @port.port_name, response.parsed_body["data"]["port_name"]
        end

        test "create persists a port" do
          assert_difference("Port.count", 1) do
            post "/api/v1/admin/master_data/ports",
                 params: { port: { port_name: "New Port" } },
                 headers: @headers, as: :json
          end

          assert_response :created
        end

        test "update modifies the port" do
          patch "/api/v1/admin/master_data/ports/#{@port.id}",
                params: { port: { port_name: "Renamed Port" } },
                headers: @headers, as: :json

          assert_response :ok
          assert_equal "Renamed Port", @port.reload.port_name
        end

        test "destroy removes the port" do
          delete "/api/v1/admin/master_data/ports/#{@port.id}", headers: @headers

          assert_response :ok
          assert_not Port.exists?(@port.id)
        end
      end
    end
  end
end
