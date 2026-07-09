require "test_helper"

module Api
  module V1
    module Approvals
      class ApprovalRemarksControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[list view create update delete].map do |action|
            Permission.find_or_create_by!(code: "approval_remarks.#{action}") do |permission|
              permission.name = "Approval remarks - #{action.capitalize}"
            end
          end
          @admin_role = create(:role, permissions: admin_permissions)
          @no_access_role = create(:role)

          @admin = create(:user, role: @admin_role, password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
          @target = create(:approval_remark)

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/approvals/approval_remarks", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/approvals/approval_remarks", headers: @admin_headers

          assert_response :ok
        end

        test "index filters by name via ransack" do
          create(:approval_remark, name: "Findable remark")

          get "/api/v1/approvals/approval_remarks", params: { q: { name_cont: "Findable" } },
                                                    headers: @admin_headers

          assert_response :ok
          assert_equal ["Findable remark"], response.parsed_body["data"].pluck("name")
        end

        test "create persists a new remark with an auto-generated reference_id" do
          assert_difference("ApprovalRemark.count", 1) do
            post "/api/v1/approvals/approval_remarks", params: { approval_remark: { name: "New remark" } },
                                                       headers: @admin_headers, as: :json
          end

          assert_response :created
          assert_match(/\AAR_\d{3}\z/, response.parsed_body.dig("data", "reference_id"))
        end

        test "create without permission is forbidden" do
          post "/api/v1/approvals/approval_remarks", params: { approval_remark: { name: "Blocked" } },
                                                     headers: @plain_headers, as: :json

          assert_response :forbidden
        end

        test "create with a duplicate name returns errors" do
          post "/api/v1/approvals/approval_remarks", params: { approval_remark: { name: @target.name } },
                                                     headers: @admin_headers, as: :json

          assert_response :unprocessable_content
          assert_predicate response.parsed_body["errors"], :present?
        end

        test "update renames the target remark" do
          patch "/api/v1/approvals/approval_remarks/#{@target.id}", params: { approval_remark: { name: "Renamed" } },
                                                                    headers: @admin_headers, as: :json

          assert_response :ok
          assert_equal "Renamed", @target.reload.name
        end

        test "destroy soft-deletes the target remark" do
          delete "/api/v1/approvals/approval_remarks/#{@target.id}", headers: @admin_headers

          assert_response :ok
          assert_predicate @target.reload, :discarded?
        end

        test "discarded remarks are excluded from index" do
          @target.discard!

          get "/api/v1/approvals/approval_remarks", headers: @admin_headers

          assert_response :ok
          assert_not_includes response.parsed_body["data"].pluck("id"), @target.id
        end
      end
    end
  end
end
