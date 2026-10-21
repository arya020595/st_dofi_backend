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

# == Schema Information
#
# Table name: zones
# Database name: primary
#
#  id           :uuid             not null, primary key
#  discarded_at :datetime
#  end_range    :integer
#  name         :string           not null
#  start_range  :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_zones_on_discarded_at  (discarded_at)
#
