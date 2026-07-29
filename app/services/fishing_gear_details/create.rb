module FishingGearDetails
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(capture_report, attributes)
      detail = capture_report.fishing_gear_details.new(attributes)
      gear = eligible_gear(capture_report, attributes[:companies_fishing_gear_id])
      return invalid_gear(detail) if attributes[:companies_fishing_gear_id].present? && gear.nil?

      detail.assign_attributes(snapshot_attributes(attributes, gear))
      return Failure(detail) unless detail.save

      Success(detail)
    end

    private

    def snapshot_attributes(attributes, gear)
      return attributes if gear.nil?

      attributes.merge(name: gear.fishing_gear.name, gear_type: gear.fishing_gear.gear_type,
                       specification: gear.fishing_gear.gear_specification)
    end

    def eligible_gear(capture_report, gear_id)
      return if gear_id.blank?

      manifest = capture_report.manifest
      CompaniesFishingGear.kept.approved.find_by(
        id: gear_id,
        company_profile_id: manifest.company_profile_id,
        companies_vessel_id: manifest.companies_vessel_id
      )
    end

    def invalid_gear(detail)
      detail.errors.add(:companies_fishing_gear_id,
                        "must reference an approved fishing gear assigned to this manifest's vessel")
      Failure(detail)
    end
  end
end
