require "test_helper"

class CompanyProfiles::SyncWorkerQuotaTest < ActiveSupport::TestCase
  test "sums max crew from kept vessels only" do
    company_profile = create(:company_profile, worker_quota: 99)
    create(:companies_vessel, company_profile:, max_crew: 12)
    discarded_vessel = create(:companies_vessel, company_profile:, max_crew: 8)
    discarded_vessel.discard

    CompanyProfiles::SyncWorkerQuota.call(company_profile)

    assert_equal 12, company_profile.reload.worker_quota
  end
end
