module ApprovalRemarks
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(remark, attributes)
      return Success(remark) if remark.update(attributes)

      Failure(remark)
    end
  end
end
