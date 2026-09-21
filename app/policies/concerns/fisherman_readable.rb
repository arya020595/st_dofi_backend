module FishermanReadable
  extend ActiveSupport::Concern

  def index?
    return true if user.fisherman?

    super
  end

  def show?
    return true if user.fisherman?

    super
  end
end
