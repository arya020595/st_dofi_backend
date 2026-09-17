require "test_helper"

class ZoneTest < ActiveSupport::TestCase
  test "discard soft-deletes without removing the row" do
    zone = create(:zone)

    zone.discard

    assert_predicate zone, :discarded?
    assert Zone.exists?(zone.id)
    assert_not Zone.kept.exists?(zone.id)
  end
end
