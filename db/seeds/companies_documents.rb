require "stringio"

admin = User.find_by!(email: "admin@dofi.gov.bn")

profiles_by_code = SEED_COMPANY_PROFILES.to_h do |definition|
  [definition[:code], CompanyProfileContact.find_by!(ic_no: definition.dig(:owner, :ic_no)).company_profile]
end

apply_approval_state = lambda do |record, approve|
  if approve
    record.resubmit!(actor: admin) if record.may_resubmit?
    record.approve!(actor: admin) if record.may_approve?
  elsif record.may_resubmit?
    record.resubmit!(actor: admin)
  end
end

pdf_body_for = lambda do |company_profile|
  <<~PDF
    %PDF-1.4
    1 0 obj
    << /Type /Catalog /Pages 2 0 R >>
    endobj
    2 0 obj
    << /Type /Pages /Kids [3 0 R] /Count 1 >>
    endobj
    3 0 obj
    << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 144] /Contents 4 0 R >>
    endobj
    4 0 obj
    << /Length 74 >>
    stream
    BT /F1 12 Tf 20 100 Td (Lorem ipsum document for #{company_profile.company_name}) Tj ET
    endstream
    endobj
    trailer
    << /Root 1 0 R >>
    %%EOF
  PDF
end

document_type_for = lambda do |definition|
  if definition[:registration_type].include?("Company") || definition[:registration_type] == "Commercial"
    "company_registration"
  else
    "white_card"
  end
end

SEED_COMPANY_PROFILES.each do |definition|
  company_profile = profiles_by_code.fetch(definition[:code])
  approved = definition[:review_state] != :pending_document
  document_type = document_type_for.call(definition)

  document = company_profile.companies_documents.find_or_initialize_by(document_type: document_type)
  unless document.file.attached?
    document.file.attach(
      io: StringIO.new(pdf_body_for.call(company_profile)),
      filename: "#{definition[:code]}-lorem-ipsum.pdf",
      content_type: "application/pdf"
    )
  end
  document.save!
  apply_approval_state.call(document, approved)
end

profiles_by_code.each_value do |company_profile|
  approvables = [
    company_profile.companies_vessels.kept.to_a,
    company_profile.companies_fishing_gears.kept.to_a,
    company_profile.companies_crews.kept.to_a,
    company_profile.companies_documents.kept.to_a
  ].flatten

  if approvables.any? && approvables.all?(&:approved?)
    CompanyProfiles::SyncApprovalStatus.refresh_after_review!(company_profile, actor: admin)
  else
    CompanyProfiles::SyncApprovalStatus.mark_pending!(company_profile)
  end
end

puts "Seeded #{CompaniesDocument.count} company documents (#{CompaniesDocument.approved.count} approved)"
puts "Profiling status distribution: #{CompanyProfile.where(approval_status: 'approved').count} approved, " \
     "#{CompanyProfile.where(approval_status: 'pending').count} pending"
