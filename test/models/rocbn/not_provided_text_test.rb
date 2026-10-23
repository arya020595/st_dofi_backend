require "test_helper"

module Rocbn
  class NotProvidedTextTest < ActiveSupport::TestCase
    setup { @type = NotProvidedText.new }

    test "the registry's markers read back as nil, whatever the case or padding" do
      ["-", "N/A", "n/a", " Not Specified ", "not specified", "", "   ", nil].each do |value|
        assert_nil @type.deserialize(value), "expected #{value.inspect} to read back as nil"
      end
    end

    test "any other text is kept, trimmed" do
      assert_equal "Kg Mumong", @type.deserialize("  Kg Mumong ")
      assert_equal "N/A Trading", @type.deserialize("N/A Trading")
    end
  end
end
