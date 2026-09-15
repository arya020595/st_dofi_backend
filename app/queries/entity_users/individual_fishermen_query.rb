module EntityUsers
  class IndividualFishermenQuery
    def self.call(scope:, registration_types:)
      scope.joins(:company_profile)
           .where(company_profiles: { registration_type: registration_types })
           .includes(:company_profile, :role)
    end
  end
end
