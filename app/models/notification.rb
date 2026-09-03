class Notification < ApplicationRecord
  belongs_to :user

  scope :unread, -> { where(read_at: nil) }
  scope :recent_first, -> { order(created_at: :desc) }

  validates :notification_type, :title, :message, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at notification_type read_at resource_id resource_type title updated_at]
  end

  def self.ransackable_associations(_auth_object = nil) = []

  def mark_read!
    update!(read_at: Time.current) unless read_at?
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
