class AddDetailFieldsToCompaniesVessels < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      change_table :companies_vessels, bulk: true do |t|
        t.string :status, null: false, default: "active" # active, non_active
        t.string :category # mother_boat, support_vessel
        t.references :zone, type: :uuid, foreign_key: true
        t.string :registration_no # "Vessel Registration No." on the certificate, distinct from boat_number
        t.integer :max_crew
        t.decimal :gross_tonnage, precision: 10, scale: 2
        t.decimal :length, precision: 10, scale: 2
        t.decimal :horse_power, precision: 10, scale: 2
        t.integer :year_built
        t.decimal :draft, precision: 10, scale: 2
        t.string :material # steel, carbon_fiber, wood
      end

      add_index :companies_vessels, :status
      add_index :companies_vessels, :registration_no
    end
  end
end
