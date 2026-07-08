module CompanyProfiles
  class Create
    include Dry::Monads[:result]

    Result = Struct.new(:owner, :admin)

    def self.call(...) = new.call(...)

    def call(attributes)
      @shared_attributes = attributes.except(:owner, :admin).merge(dofi_registration_no: next_dofi_registration_no)
      owner = nil
      admin = nil

      ActiveRecord::Base.transaction do
        owner = create_profile!(attributes[:owner], designation: "Owner")
        admin = create_profile!(attributes[:admin], designation: "Admin") if present_attributes?(attributes[:admin])
      end

      Success(Result.new(owner, admin))
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record)
    end

    private

    def create_profile!(person_attributes, designation:)
      CompanyProfile.create!(@shared_attributes.merge(person_attributes).merge(
                               reference_id: next_reference_id, designation: designation
                             ))
    end

    def present_attributes?(sub_params)
      sub_params.present? && sub_params.to_h.values.any?(&:present?)
    end

    def next_dofi_registration_no
      year = Time.current.year
      next_num = CompanyProfile.where("dofi_registration_no LIKE ?", "DoFi-#{year}-%")
                               .maximum("CAST(SUBSTRING(dofi_registration_no FROM 11) AS INTEGER)") || 0
      format("DoFi-%<year>d-%<num>03d", year: year, num: next_num + 1)
    end

    def next_reference_id
      next_num = CompanyProfile.where("reference_id LIKE ?", "REG-DOF-%")
                               .maximum("CAST(SUBSTRING(reference_id FROM 9) AS INTEGER)") || 0
      format("REG-DOF-%03d", next_num + 1)
    end
  end
end
