class DictionaryPolicy < ApplicationPolicy
  include FishermanReadable

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def permission_resource = "dictionaries"
end
