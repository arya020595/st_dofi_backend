class DictionaryGroupPolicy < ApplicationPolicy
  RESOURCE = "dictionary_groups".freeze

  def index? = user.permission?("#{RESOURCE}.list")
  def show? = user.permission?("#{RESOURCE}.view")
  def create? = user.permission?("#{RESOURCE}.create")
  def update? = user.permission?("#{RESOURCE}.update")
  def destroy? = user.permission?("#{RESOURCE}.delete")

  class Scope < Scope
    def resolve = scope.all
  end
end
