class RocbnCompanyBlueprint < Blueprinter::Base
  # The registry's own row id as an opaque string: the value the detail endpoint takes back.
  field(:id) { |company| company.id.to_s }

  fields :rocbn_number, :company_name, :company_address
end
