module Users
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      user = User.new(attributes.except(:employee_id).merge(employee_id: next_employee_id))
      return Success(user) if user.save

      Failure(user)
    end

    private

    def next_employee_id
      next_num = User.where("employee_id LIKE ?", "DOF-%")
                     .maximum("CAST(SUBSTRING(employee_id FROM 5) AS INTEGER)") || 0
      format("DOF-%03d", next_num + 1)
    end
  end
end
