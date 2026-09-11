require "test_helper"

module Roles
  class PermissionPlatformValidationTest < ActiveSupport::TestCase
    test "create rejects a legacy code even while its permission row still exists" do
      legacy = create(:permission, code: "manifest_form.create")

      result = Roles::Create.call(
        { name: "Legacy Role" }, platform_scope: Role::DOFI_OFFICER_PLATFORM, permission_codes: [legacy.code]
      )

      assert_equal [true, false, ["Permission codes includes unknown codes: manifest_form.create"]],
                   [result.failure?, result.failure.persisted?, result.failure.errors.full_messages]
    end

    test "update rejects a legacy code without changing existing assignments" do
      current = create(:permission, code: "manifests.view")
      legacy = create(:permission, code: "profiling.view")
      role = create(:role, permissions: [current])

      result = Roles::Update.call(
        role,
        { name: "Not saved" },
        platform_scope: Role::DOFI_OFFICER_PLATFORM,
        permission_codes: [legacy.code]
      )

      assert_equal [true, [current.code]], [result.failure?, role.reload.permissions.pluck(:code)]
    end
  end
end
