require "test_helper"

class ManifestMinorFishermanTest < ActiveSupport::TestCase
  test "invalid without full_name, date_of_birth, gender, or relationship_with_owner" do
    minor = build(:manifest_minor_fisherman, full_name: nil, date_of_birth: nil, gender: nil,
                                             relationship_with_owner: nil)

    minor.valid?

    assert_equal %i[date_of_birth full_name gender relationship_with_owner],
                 minor.errors.attribute_names.sort
  end
end
