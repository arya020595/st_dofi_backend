require "test_helper"

class PortTest < ActiveSupport::TestCase
  test "discard soft-deletes without removing the row" do
    port = create(:port)

    port.discard

    assert_predicate port, :discarded?
    assert Port.exists?(port.id)
    assert_not Port.kept.exists?(port.id)
  end
end
