module ManifestExpenses
  class Upsert
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, attributes)
      expense = manifest.manifest_expense || manifest.build_manifest_expense
      return Success(expense) if expense.update(attributes)

      Failure(expense)
    end
  end
end
