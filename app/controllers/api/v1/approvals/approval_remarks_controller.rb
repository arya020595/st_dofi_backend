module Api
  module V1
    module Approvals
      class ApprovalRemarksController < ApplicationController
        include RansackSearchable

        before_action :set_approval_remark, only: %i[show update destroy]

        def index
          authorize ApprovalRemark
          result = apply_ransack_search(policy_scope(ApprovalRemark), default_sort: "reference_id asc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: ApprovalRemarkBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @approval_remark
          render json: { status: "success", data: ApprovalRemarkBlueprint.render_as_hash(@approval_remark) }
        end

        def create
          authorize ApprovalRemark

          case ApprovalRemarks::Create.call(approval_remark_params)
          in Success(remark)
            render json: { status: "success", data: ApprovalRemarkBlueprint.render_as_hash(remark) },
                   status: :created
          in Failure(remark)
            render json: { status: "fail", errors: remark.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @approval_remark

          case ApprovalRemarks::Update.call(@approval_remark, approval_remark_params)
          in Success(remark)
            render json: { status: "success", data: ApprovalRemarkBlueprint.render_as_hash(remark) }
          in Failure(remark)
            render json: { status: "fail", errors: remark.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @approval_remark

          if @approval_remark.discard
            render json: { status: "success", message: "Approval remark removed." }
          else
            render json: { status: "fail", errors: @approval_remark.errors.full_messages },
                   status: :unprocessable_content
          end
        end

        private

        def set_approval_remark
          @approval_remark = ApprovalRemark.find(params.expect(:id))
        end

        def approval_remark_params
          params.expect(approval_remark: %i[name])
        end
      end
    end
  end
end
