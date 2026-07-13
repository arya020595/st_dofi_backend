class CompanyProfileContactLookupBlueprint < Blueprinter::Base
  identifier :id

  fields :full_name, :ic_no, :designation

  field(:registration_type) { |contact| contact.company_profile.registration_type }
  field(:company_name) { |contact| contact.company_profile.company_name }
  field(:rocbn_no) { |contact| contact.company_profile.rocbn_no }
end
