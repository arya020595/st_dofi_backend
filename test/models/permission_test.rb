require "test_helper"

class PermissionTest < ActiveSupport::TestCase
  test "derives resource and grouping metadata from a catalog permission" do
    permission = create(:permission, code: "ports.create", name: "Ports - Create")

    assert_equal "ports", permission.resource
    assert_equal({ section: "master_data", section_order: 5, resource_order: 1 }, grouping(permission))
  end

  test "leaves grouping nil for a resource outside the catalog" do
    permission = create(:permission)

    assert_match(/\Aresource_\d+\z/, permission.resource)
    assert_equal({ section: nil, section_order: nil, resource_order: nil }, grouping(permission))
    assert_predicate permission, :valid?
  end

  test "re-derives resource and grouping when code changes rather than keeping stale values" do
    permission = create(:permission, code: "ports.create", name: "Ports - Create")

    permission.update!(code: "dashboard.list", name: "Dashboard - List")

    assert_equal "dashboard", permission.resource
    assert_equal({ section: "dashboard", section_order: 1, resource_order: 1 }, grouping(permission))
  end

  test "does not allow resource or grouping fields to be set independently of code" do
    permission = build(:permission, code: "ports.create", name: "Wrong", platform_scope: "shared",
                                    resource: "something_else", section: "not_a_real_section")

    permission.valid?

    assert_equal %w[Create dofi_officer ports master_data],
                 [permission.name, permission.platform_scope, permission.resource, permission.section]
  end

  test "resource_label and section_label return the catalog labels" do
    permission = create(:permission, code: "ports.create", name: "Ports - Create")

    assert_equal ["create", 3, "Ports", "Master Data"],
                 [permission.action, permission.action_order, permission.resource_label, permission.section_label]
  end

  test "resource and section labels fall back for a resource outside the catalog" do
    permission = create(:permission, code: "widgets.view")

    assert_equal "Widgets", permission.resource_label
    assert_nil permission.section_label
  end

  private

  def grouping(permission)
    { section: permission.section, section_order: permission.section_order, resource_order: permission.resource_order }
  end
end

# == Schema Information
#
# Table name: permissions
# Database name: primary
#
#  id             :uuid             not null, primary key
#  code           :string           not null
#  name           :string           not null
#  platform_scope :string           default("shared"), not null
#  resource       :string           not null
#  resource_order :integer
#  section        :string
#  section_order  :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_permissions_on_code  (code) UNIQUE
#
