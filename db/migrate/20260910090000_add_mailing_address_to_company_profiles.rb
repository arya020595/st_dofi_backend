class AddMailingAddressToCompanyProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :company_profiles, :mailing_address, :text
  end
end
