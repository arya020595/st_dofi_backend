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

# == Schema Information
#
# Table name: ports
# Database name: primary
#
#  id           :uuid             not null, primary key
#  discarded_at :datetime
#  latitude     :decimal(10, 8)
#  longitude    :decimal(11, 8)
#  port_name    :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_ports_on_discarded_at  (discarded_at)
#  index_ports_on_port_name     (port_name)
#
