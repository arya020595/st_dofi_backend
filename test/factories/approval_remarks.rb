FactoryBot.define do
  factory :approval_remark do
    sequence(:name) { |n| "Test Remark #{n}" }
    usage_scope { "both" }
  end
end

# == Schema Information
#
# Table name: approval_remarks
# Database name: primary
#
#  id           :uuid             not null, primary key
#  discarded_at :datetime
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_approval_remarks_on_discarded_at  (discarded_at)
#  index_approval_remarks_on_name          (name) UNIQUE
#
