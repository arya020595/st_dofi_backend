module ApprovalRemarks
  class FindApplicable
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(id:, action:)
      remark = ApprovalRemark.kept.find_by(id: id)
      return Failure(:invalid_approval_remark) if remark.nil?
      return Failure(:approval_remark_not_applicable) unless remark.applicable_to?(action)

      Success(remark)
    end
  end
end
