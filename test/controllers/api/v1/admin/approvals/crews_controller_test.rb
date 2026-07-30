require "test_helper"

module Api
  module V1
    module Approvals
      class CrewsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[view list approve amendment].map do |action|
            Permission.find_or_create_by!(code: "companies_crew_approvals.#{action}") do |p|
              p.name = "Approvals - #{action}"
            end
          end
          @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
          @no_access_role = create(:role)

          @admin = create(:user, role: @admin_role, position: "Administrator", unit: "HQ",
                                 password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
          @crew = create(:companies_crew)

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/admin/approvals/crews", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/admin/approvals/crews", headers: @admin_headers

          assert_response :ok
        end

        test "approve transitions the crew member from pending to approved" do
          post "/api/v1/admin/approvals/crews/#{@crew.id}/approve", headers: @admin_headers

          assert_response :ok
          assert_equal "approved", @crew.reload.approval_status
        end

        test "request_amendment records the remarks and moves the crew member to amendment_required" do
          post "/api/v1/admin/approvals/crews/#{@crew.id}/request_amendment",
               params: { remarks: "IC number invalid" }, headers: @admin_headers, as: :json

          assert_response :ok
          assert_equal "amendment_required", @crew.reload.approval_status
        end
      end
    end
  end
end
