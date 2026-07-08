module Users
  class RejectRegistration
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(user, approval_remark_id:)
      return Failure(user) unless user.may_reject?

      approval_remark = ApprovalRemark.kept.find_by(id: approval_remark_id)
      if approval_remark.nil?
        user.errors.add(:approval_remark_id, "is invalid")
        return Failure(user)
      end

      user.rejection_reason = approval_remark.name
      user.reject!
      Success(user)
    end
  end
end
