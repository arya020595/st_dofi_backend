FactoryBot.define do
  factory :notification do
    user
    sequence(:notification_type) { |n| "manifest.port_out_approved_#{n}" }
    title { "Port-Out Approved" }
    message { "Your manifest has been approved." }
    metadata { {} }
  end
end

# == Schema Information
#
# Table name: notifications
# Database name: primary
#
#  id                :uuid             not null, primary key
#  message           :text             not null
#  metadata          :jsonb            not null
#  notification_type :string           not null
#  read_at           :datetime
#  resource_type     :string
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  resource_id       :uuid
#  user_id           :uuid             not null
#
# Indexes
#
#  index_notifications_for_user_inbox                    (user_id,read_at,created_at)
#  index_notifications_on_resource_type_and_resource_id  (resource_type,resource_id)
#  index_notifications_on_user_id                        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
