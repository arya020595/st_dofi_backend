class AddGenderStatusAndForeignWorkerLicenseToCompaniesCrews < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      change_table :companies_crews, bulk: true do |t|
        t.string :gender
        t.string :status, null: false, default: "active" # active, non_active
        t.string :foreign_worker_license_no
        t.date :foreign_worker_license_start_date
        t.date :foreign_worker_license_end_date
      end

      add_index :companies_crews, :status
    end
  end
end
