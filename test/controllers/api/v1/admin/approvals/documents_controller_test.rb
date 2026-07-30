require "test_helper"

module Api
  module V1
    module Approvals
      class DocumentsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[view list approve amendment].map do |action|
            Permission.find_or_create_by!(code: "companies_document_approvals.#{action}") do |p|
              p.name = "Document Approvals - #{action}"
            end
          end
          @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
          @no_access_role = create(:role)

          @admin = create(:user, role: @admin_role, position: "Administrator", unit: "HQ",
                                 password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
          @document = create(:companies_document)

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/admin/approvals/documents", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/admin/approvals/documents", headers: @admin_headers

          assert_response :ok
        end

        test "approve transitions the document from pending to approved" do
          post "/api/v1/admin/approvals/documents/#{@document.id}/approve", headers: @admin_headers

          assert_response :ok
          assert_equal "approved", @document.reload.approval_status
        end

        test "approve without permission is forbidden" do
          post "/api/v1/admin/approvals/documents/#{@document.id}/approve", headers: @plain_headers

          assert_response :forbidden
        end

        test "request_amendment records the remarks and moves the document to amendment_required" do
          post "/api/v1/admin/approvals/documents/#{@document.id}/request_amendment",
               params: { remarks: "Scan is illegible" }, headers: @admin_headers, as: :json

          assert_response :ok
          @document.reload

          assert_equal "amendment_required", @document.approval_status
          assert_equal "Scan is illegible", @document.amendment_remarks
        end
      end
    end
  end
end
