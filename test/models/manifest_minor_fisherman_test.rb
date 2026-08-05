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

# == Schema Information
#
# Table name: manifest_minor_fishermen
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  date_of_birth           :date             not null
#  full_name               :string           not null
#  gender                  :string           not null
#  relationship_with_owner :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  manifest_id             :uuid             not null
#
# Indexes
#
#  index_manifest_minor_fishermen_on_manifest_id  (manifest_id)
#
# Foreign Keys
#
#  fk_rails_...  (manifest_id => manifests.id)
#
