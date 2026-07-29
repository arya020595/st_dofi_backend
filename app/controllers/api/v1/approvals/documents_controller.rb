module Api
  module V1
    module Approvals
      class DocumentsController < ApplicationController
        include RansackSearchable

        before_action :set_document, only: %i[show approve request_amendment]

        def index
          authorize CompaniesDocument, policy_class: CompaniesDocumentApprovalPolicy
          result = apply_ransack_search(document_scope, default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: CompaniesDocumentApprovalBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @document, policy_class: CompaniesDocumentApprovalPolicy
          render json: { status: "success", data: CompaniesDocumentApprovalBlueprint.render_as_hash(@document) }
        end

        def approve
          authorize @document, policy_class: CompaniesDocumentApprovalPolicy

          case CompaniesDocuments::Approve.call(@document, actor: current_user)
          in Success(document)
            render json: { status: "success", data: CompaniesDocumentApprovalBlueprint.render_as_hash(document) }
          in Failure(document)
            render json: { status: "fail", errors: document.errors.full_messages }, status: :unprocessable_content
          end
        end

        def request_amendment
          authorize @document, policy_class: CompaniesDocumentApprovalPolicy

          result = CompaniesDocuments::RequestAmendment.call(@document, actor: current_user,
                                                                        remarks: params.expect(:remarks))
          case result
          in Success(document)
            render json: { status: "success", data: CompaniesDocumentApprovalBlueprint.render_as_hash(document) }
          in Failure(document)
            render json: { status: "fail", errors: document.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def document_scope
          policy_scope(CompaniesDocument, policy_scope_class: CompaniesDocumentApprovalPolicy::Scope)
        end

        def set_document
          @document = document_scope.find(params.expect(:id))
        end
      end
    end
  end
end
