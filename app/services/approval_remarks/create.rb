module ApprovalRemarks
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      remark = ApprovalRemark.new(attributes.merge(reference_id: next_reference_id))
      return Failure(remark) unless remark.save

      Success(remark)
    end

    private

    def next_reference_id
      next_num = ApprovalRemark.where("reference_id LIKE ?", "AR\\_%")
                               .maximum("CAST(SUBSTRING(reference_id FROM 4) AS INTEGER)") || 0
      format("AR_%03d", next_num + 1)
    end
  end
end
