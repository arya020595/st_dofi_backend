module Fisherman
  class ProvisioningRequest
    def initialize(attributes)
      @attributes = attributes
    end

    def company_profile = attributes.fetch(:company_profile)
    def provisioning_source = attributes.fetch(:provisioning_source)
    def created_by = attributes.fetch(:created_by)
    def name = attributes.fetch(:name)
    def ic_number = attributes.fetch(:ic_number)
    def company_profile_contact = attributes[:company_profile_contact]
    def role = attributes[:role]

    private

    attr_reader :attributes
  end
end
