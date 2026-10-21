class ManifestHistory < ApplicationRecord
  belongs_to :manifest
  belongs_to :changed_by, class_name: "User", optional: true

  validates :action, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id manifest_id action status_type from_state to_state changed_by_id created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

# == Schema Information
#
# Table name: manifest_histories
# Database name: primary
#
#  id            :uuid             not null, primary key
#  action        :string           not null
#  from_state    :string
#  metadata      :jsonb
#  remarks       :text
#  status_type   :string
#  to_state      :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  changed_by_id :uuid
#  manifest_id   :uuid             not null
#
# Indexes
#
#  index_manifest_histories_on_changed_by_id  (changed_by_id)
#  index_manifest_histories_on_manifest_id    (manifest_id)
#
# Foreign Keys
#
#  fk_rails_...  (changed_by_id => users.id)
#  fk_rails_...  (manifest_id => manifests.id)
#
