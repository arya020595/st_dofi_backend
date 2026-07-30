require "test_helper"

module Api
  module V1
    module CompanyProfiles
      class DocumentsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[view list create update].map do |action|
            Permission.find_or_create_by!(code: "companies_documents.#{action}") do |p|
              p.name = "Documents - #{action}"
            end
          end
          @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
          @no_access_role = create(:role)

          @admin = create(:user, role: @admin_role, position: "Administrator", unit: "HQ",
                                 password: @password, password_confirmation: @password)
          @company_profile = create(:company_profile)
          @plain_user = create(:user, role: @no_access_role, company_profile: @company_profile,
                                      password: @password, password_confirmation: @password)

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/company_profiles/#{@company_profile.id}/documents", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/company_profiles/#{@company_profile.id}/documents", headers: @admin_headers

          assert_response :ok
        end

        test "create adds a pending document under the company" do
          params = { document: { document_type: "white_card",
                                 file: fixture_file_upload("sample.pdf", "application/pdf") } }

          assert_difference("CompaniesDocument.count", 1) do
            post "/api/v1/company_profiles/#{@company_profile.id}/documents", params: params, headers: @admin_headers
          end

          assert_response :created
        end

        test "create returns the document_type, pending approval_status, and a private attachment URL" do
          params = { document: { document_type: "white_card",
                                 file: fixture_file_upload("sample.pdf", "application/pdf") } }

          post "/api/v1/company_profiles/#{@company_profile.id}/documents", params: params, headers: @admin_headers
          data = response.parsed_body["data"]

          assert_equal "pending", data["approval_status"]
          assert_equal "white_card", data["document_type"]
          assert_includes data["document_url"], "/api/v1/attachments/"
        end

        test "create rejects a non-PDF upload" do
          tempfile = Tempfile.new(["fake", ".pdf"])
          tempfile.write("<!DOCTYPE html><script>alert(document.cookie)</script>")
          tempfile.rewind
          spoofed_file = Rack::Test::UploadedFile.new(tempfile.path, "application/pdf")
          params = { document: { document_type: "white_card", file: spoofed_file } }

          assert_no_difference("CompaniesDocument.count") do
            post "/api/v1/company_profiles/#{@company_profile.id}/documents", params: params, headers: @admin_headers
          end

          assert_response :unprocessable_content
        ensure
          tempfile&.close!
        end

        test "update replaces the file and reverts approval_status to pending" do
          document = create(:companies_document, :approved, company_profile: @company_profile)
          params = { document: { file: fixture_file_upload("sample.pdf", "application/pdf") } }

          patch "/api/v1/company_profiles/#{@company_profile.id}/documents/#{document.id}",
                params: params, headers: @admin_headers

          assert_response :ok
          assert_equal "pending", document.reload.approval_status
        end
      end
    end
  end
end
