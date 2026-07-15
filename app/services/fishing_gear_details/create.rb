module FishingGearDetails
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(capture_report, attributes)
      gear = CompaniesFishingGear.kept.find_by(id: attributes[:companies_fishing_gear_id])
      detail = capture_report.fishing_gear_details.new(build_attributes(attributes, gear))
      return Failure(detail) unless detail.save

      Success(detail)
    end

    private

    def build_attributes(attributes, gear)
      return attributes if gear.nil?

      attributes.merge(name: gear.fishing_gear.name, gear_type: gear.fishing_gear.gear_type,
                       specification: gear.fishing_gear.gear_specification)
    end
  end
end
