module ApprovalRemarks
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      remark = ApprovalRemark.new(attributes)
      return Failure(remark) unless remark.save

      Success(remark)
    end
  end
end
