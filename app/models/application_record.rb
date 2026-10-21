class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Primary keys are random UUIDs (gen_random_uuid()), not sequential, so .first/.last need an
  # explicit ordering column to be meaningful — otherwise they sort by UUID string value.
  self.implicit_order_column = "created_at"
end
