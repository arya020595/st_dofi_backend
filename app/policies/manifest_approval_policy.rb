class ManifestApprovalPolicy < ApplicationPolicy
  def tab_counts? = index?
  def approve? = permitted?("approve")
  def request_amendment? = permitted?("request_amendment")

  class Scope < ApplicationPolicy::Scope
    # Jetty Managers see Commercial and Small-Scale (Company) manifests only; individual Full-Time/Part-Time
    # fishermen are hidden from them. DoFi Officers keep the full list.
    # See docs/manifests/approval-rules-by-category.md.
    JETTY_MANAGER_CATEGORIES = [Manifest::FishermanCategory::COMMERCIAL,
                                Manifest::FishermanCategory::SMALL_SCALE_COMPANY].freeze

    def resolve
      kept = scope.kept
      return kept unless user.jetty_manager?

      kept.where(fisherman_category: JETTY_MANAGER_CATEGORIES)
    end
  end

  private

  def permission_resource = "manifest_approvals"
end
