module Manifests
  module ExpenseReadable
    extend ActiveSupport::Concern
    include Manifests::ManifestScoped

    def show
      authorize @manifest, policy_class: manifest_policy_class

      expense = @manifest.manifest_expense
      if expense
        render json: { status: "success", data: ManifestExpenseBlueprint.render_as_hash(expense) }
      else
        render json: { status: "fail", errors: ["Expense not found"] }, status: :not_found
      end
    end

    private

    def manifest_policy_class = ManifestPolicy
  end
end
