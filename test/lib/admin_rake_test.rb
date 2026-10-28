require "test_helper"
require "rake"

class AdminRakeTest < ActiveSupport::TestCase
  include DirectoryTestSupport

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.none? { it.name == "admin:assign_ad_username" }
    @staff = create(:user, :officer_shaped, role: create(:role, kind: Role::DOFI_OFFICER),
                                            email: "admin@dofi.gov.bn", username: "mprt/dof-001")
  end

  def assign(email: "admin@dofi.gov.bn", username: "mprt/real.name")
    task = Rake::Task["admin:assign_ad_username"]
    task.reenable
    with_env({ "EMAIL" => email, "AD_USERNAME" => username }) { capture_io { task.invoke } }
  end

  test "remaps the staff user to the real AD name and revokes its tokens" do
    jti = @staff.jti
    assign(username: "Real.Name")

    assert_equal "mprt/real.name", @staff.reload.username
    assert_not_equal jti, @staff.jti
  end

  test "refuses a name that is not an AD name, a name already used, an unknown user and a non-staff user" do
    create(:user, username: "mprt/taken.name")
    jetty = create(:user, :jetty_manager_shaped, role: create(:role, kind: Role::JETTY_MANAGER),
                                                 email: "jm@example.test")

    [[{ username: "not valid!" }], [{ username: "mprt/taken.name" }], [{ username: "taken.name" }],
     [{ email: "nobody@example.test" }], [{ email: jetty.email }], [{ username: nil }]].each do |(args)|
      assert_raises(SystemExit, args.inspect) { assign(**args) }
    end
    assert_equal "mprt/dof-001", @staff.reload.username
  end
end
