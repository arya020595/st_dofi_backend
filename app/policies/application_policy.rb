class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = permitted?("list")
  def show? = permitted?("view")
  def create? = permitted?("create")
  def new? = create?
  def update? = permitted?("update")
  def edit? = update?
  def destroy? = permitted?("delete")

  private

  def permitted?(action)
    user.permission?(build_permission_code(action))
  end

  def build_permission_code(action)
    "#{permission_resource}.#{action}"
  end

  def permission_resource
    raise NotImplementedError, "#{self.class.name} must implement #permission_resource"
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end
  end
end
