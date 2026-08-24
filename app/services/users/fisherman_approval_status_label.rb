module Users
  class FishermanApprovalStatusLabel
    LABELS = {
      "pending_approval" => "Pending",
      "claimable" => "Approved",
      "active" => "Active",
      "suspended" => "Suspended",
      "revoked" => "Revoked"
    }.freeze

    def self.call(status)
      LABELS.fetch(status, status.to_s.humanize)
    end
  end
end
