class CompaniesDocument < ApplicationRecord
  include Discard::Model
  include Approvable

  DOCUMENT_TYPES = %w[
    company_registration
    surat_tawaran
    foreign_worker_license
    white_card
    fishing_gear_license
  ].freeze

  ALLOWED_CONTENT_TYPES = %w[application/pdf].freeze
  MAX_FILE_SIZE = 10.megabytes

  belongs_to :company_profile
  has_one_attached :file

  validates :document_type, presence: true, inclusion: { in: DOCUMENT_TYPES }
  validates :document_type, uniqueness: { scope: :company_profile_id, conditions: -> { kept } }
  validates :file, presence: true
  validate :file_content_type_and_size, if: -> { file.attached? }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id document_type approval_status amendment_remarks company_profile_id discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def file_content_type_and_size
    errors.add(:file, "must be a PDF") unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
    errors.add(:file, "must be smaller than 10 MB") if file.byte_size > MAX_FILE_SIZE
  end
end

# == Schema Information
#
# Table name: companies_documents
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  amendment_remarks  :text
#  approval_status    :string           default("pending"), not null
#  approved_at        :datetime
#  discarded_at       :datetime
#  document_type      :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  approved_by_id     :uuid
#  company_profile_id :uuid             not null
#
# Indexes
#
#  index_companies_documents_on_approved_by_id         (approved_by_id)
#  index_companies_documents_on_company_profile_id     (company_profile_id)
#  index_companies_documents_on_discarded_at           (discarded_at)
#  index_companies_documents_on_profile_and_type_kept  (company_profile_id,document_type) UNIQUE WHERE (discarded_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#
