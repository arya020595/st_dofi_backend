module Permission::CatalogRecord
  extend ActiveSupport::Concern

  included do
    before_validation :sync_catalog_metadata
    validates :resource, presence: true
  end

  def resource_label = catalog_entry&.fetch(:resource_label) || resource&.humanize
  def section_label = catalog_entry&.fetch(:section_label) || section&.humanize
  def action = catalog_entry&.fetch(:action) || code.to_s.split(".", 2).last
  def action_order = catalog_entry&.fetch(:action_order)

  private

  def catalog_entry = Permission::Catalog::BY_CODE[code]

  def sync_catalog_metadata
    self.resource = code.to_s.split(".", 2).first
    entry = catalog_entry
    entry ? apply_catalog_entry(entry) : clear_grouping
  end

  def apply_catalog_entry(entry)
    self.name = entry.fetch(:name)
    self.platform_scope = entry.fetch(:platform_scope)
    self.section = entry.fetch(:section)
    self.section_order = entry.fetch(:section_order)
    self.resource_order = entry.fetch(:resource_order)
  end

  def clear_grouping
    self.section = nil
    self.section_order = nil
    self.resource_order = nil
  end
end
