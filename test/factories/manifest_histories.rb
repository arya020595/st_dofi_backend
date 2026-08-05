FactoryBot.define do
  factory :manifest_history do
    manifest
    action { "submit_port_out" }
    status_type { "port_out_status" }
    from_state { "draft" }
    to_state { "pending" }
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
