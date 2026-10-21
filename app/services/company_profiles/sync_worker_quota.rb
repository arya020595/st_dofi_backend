module CompanyProfiles
  class SyncWorkerQuota
    def self.call(...) = new.call(...)

    def call(company_profile)
      company_profile.update!(worker_quota: worker_quota_for(company_profile))
    end

    private

    def worker_quota_for(company_profile)
      company_profile.companies_vessels.kept.sum(:max_crew)
    end
  end
end
