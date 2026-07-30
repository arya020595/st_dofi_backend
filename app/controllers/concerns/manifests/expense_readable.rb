module Manifests
  module ExpenseReadable
    extend ActiveSupport::Concern
    include Manifests::ManifestScoped

    def show
      authorize expense_record, :show?

      expense = @manifest.manifest_expense
      if expense
        render json: { status: "success", data: ManifestExpenseBlueprint.render_as_hash(expense) }
      else
        render json: { status: "fail", errors: ["Expense not found"] }, status: :not_found
      end
    end

    private

    def expense_record
      @manifest.manifest_expense || ManifestExpense.new(manifest_id: @manifest.id)
    end
  end
end
