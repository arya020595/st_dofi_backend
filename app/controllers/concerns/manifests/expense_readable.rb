module Manifests
  module ExpenseReadable
    extend ActiveSupport::Concern
    include Manifests::ManifestScoped

    def show
      authorize @manifest

      expense = @manifest.manifest_expense
      if expense
        render json: { status: "success", data: ManifestExpenseBlueprint.render_as_hash(expense) }
      else
        render json: { status: "fail", errors: ["Expense not found"] }, status: :not_found
      end
    end
  end
end
