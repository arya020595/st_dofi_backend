module Rocbn
  # A row of the registry's sync_rocbn_hotel table: a company, repeated once per director/shareholder. Strictly
  # read-only: readonly? here, `replica: true` on the connection (config/rocbn.yml) and a SELECT-only database
  # account all refuse a write independently. The API names (rocbn_number, company_name, ...) are the contract with
  # the frontend; the registry's own column names stay inside this class.
  class Company < BaseRecord
    self.table_name = "sync_rocbn_hotel"

    # The person-level columns hold a director's or shareholder's identity data. This lookup never needs them, so
    # they are ignored: they can't be selected, serialised or logged by accident.
    self.ignored_columns += %w[role type_of_role identity_type identity_number nationality person_name
                               date_of_birth position gender appointment_date old_value]

    # What the Search Company table shows; the detail endpoint reads every non-ignored column.
    LIST_COLUMNS = %i[id registration_no name address_1 address_2 address_3].freeze

    %i[address_1 address_2 address_3 telp district mukim village].each do |column|
      attribute column, NotProvidedText.new
    end

    alias_attribute :rocbn_number, :registration_no
    alias_attribute :company_name, :name
    alias_attribute :contact_number, :telp

    # Same name as Discard's scope so the policy scope reads like every other one; the column is the registry's
    # own (Laravel soft delete), and this model never discards anything.
    scope :kept, -> { where(deleted_at: nil) }
    # A stable order (name, then id) and only the columns the list shows. Client sorts are ignored, see below.
    scope :for_listing, -> { select(*LIST_COLUMNS).order(:name, :id) }

    # The public search vocabulary. Self-contained on purpose: each reads only this table's column.
    ransacker :company_name, formatter: ->(value) { value.to_s.squish } do |parent|
      parent.table[:name]
    end

    ransacker :rocbn_number, formatter: ->(value) { value.to_s.strip } do |parent|
      parent.table[:registration_no]
    end

    def self.ransackable_attributes(_auth_object = nil) = %w[company_name rocbn_number]
    def self.ransackable_associations(_auth_object = nil) = []
    # for_listing fixes the order; a client sort could only make pages unstable.
    def self.ransortable_attributes(_auth_object = nil) = []

    def readonly? = true

    def company_address = [address_1, address_2, address_3].compact.join(", ").presence
  end
end
