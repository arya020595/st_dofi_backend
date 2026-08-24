require "test_helper"

module IcNumbers
  class NormalizeTest < ActiveSupport::TestCase
    test "normalizes punctuation and case" do
      assert_equal "01123456", Normalize.call("01-123456")
      assert_equal "01123456", Normalize.call("01 123456")
      assert_equal "A123456", Normalize.call("a-123456")
    end

    test "handles nil without raising" do
      assert_equal "", Normalize.call(nil)
    end
  end
end
