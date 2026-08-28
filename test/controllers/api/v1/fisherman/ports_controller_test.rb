require "test_helper"

module Api
  module V1
    module Fisherman
      class PortsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          fisherman_permissions = %w[manifest_list.view manifest_form.view].map do |code|
            Permission.find_or_create_by!(code: code) { |p| p.name = code }
          end

          @fisherman_role = create(:role, :fisherman, name: "Fisherman", permissions: fisherman_permissions)
          @no_access_role = create(:role)

          @fisherman = create(:user, role: @fisherman_role, ic_number: "01-800100", registration_type: "Commercial",
                                     password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)

          @fisherman_headers = auth_headers_for(@fisherman, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires manifest access permission" do
          get "/api/v1/fisherman/master_data/ports", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/fisherman/master_data/ports", headers: @fisherman_headers

          assert_response :ok
        end

        test "index defaults to port_name ascending" do
          create(:port, port_name: "Zeta Port")
          create(:port, port_name: "Alpha Port")

          get "/api/v1/fisherman/master_data/ports", headers: @fisherman_headers

          assert_response :ok
          names = response.parsed_body["data"].pluck("port_name")

          assert_equal names.sort, names
        end

        test "show returns the port" do
          port = create(:port, port_name: "Muara Port")

          get "/api/v1/fisherman/master_data/ports/#{port.id}", headers: @fisherman_headers

          assert_response :ok
          assert_equal "Muara Port", response.parsed_body["data"]["port_name"]
        end
      end
    end
  end
end
