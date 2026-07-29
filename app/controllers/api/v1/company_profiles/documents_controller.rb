module Api
  module V1
    module CompanyProfiles
      class DocumentsController < ApplicationController
        include RansackSearchable

        before_action :set_company_profile
        before_action :set_document, only: %i[update]

        def index
          authorize CompaniesDocument
          result = apply_ransack_search(policy_scope(@company_profile.companies_documents),
                                        default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: CompaniesDocumentBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def create
          authorize CompaniesDocument

          case CompaniesDocuments::Create.call(@company_profile, document_params)
          in Success(document)
            render json: { status: "success", data: CompaniesDocumentBlueprint.render_as_hash(document) },
                   status: :created
          in Failure(document)
            render json: { status: "fail", errors: document.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @document

          case CompaniesDocuments::Update.call(@document, params.expect(document: %i[file])[:file])
          in Success(document)
            render json: { status: "success", data: CompaniesDocumentBlueprint.render_as_hash(document) }
          in Failure(document)
            render json: { status: "fail", errors: document.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_company_profile
          @company_profile = policy_scope(CompanyProfile).find(params.expect(:company_profile_id))
        end

        def set_document
          @document = @company_profile.companies_documents.kept.find(params.expect(:id))
        end

        def document_params
          params.expect(document: %i[document_type file])
        end
      end
    end
  end
end
