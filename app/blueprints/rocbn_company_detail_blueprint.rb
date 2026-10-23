class RocbnCompanyDetailBlueprint < Blueprinter::Base
  field(:id) { |company| company.id.to_s }

  # What the Add Profiling form autofills. A value the registry does not provide is null, never a placeholder.
  fields :rocbn_number, :company_name, :company_address, :contact_number, :district, :mukim, :village
end
