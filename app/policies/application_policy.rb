class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def new? = create?
  def update? = false
  def edit? = update?
  def destroy? = false

  private

  def fisherman_platform?
    user&.fisherman?
  end

  def fisherman_manifest_read?
    user.permission?("manifest.view", "manifest.create", "manifest_list.view", "manifest_form.view",
                     "manifest_form.create")
  end

  def fisherman_manifest_write?
    user.permission?("manifest.create", "manifest_form.create")
  end

  def fisherman_manifest_delete?
    user.permission?("manifest.delete", "manifest_list.delete")
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
