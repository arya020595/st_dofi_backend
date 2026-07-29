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
