module Notifications
  class ManifestRecipients
    APPROVAL_PERMISSION = "manifest_approvals.approve".freeze
    CAPTURE_VERIFICATION_PERMISSION = "capture_report_verifications.verify".freeze

    def self.resolve(...) = new(...).call

    def initialize(manifest:, permission_code: nil)
      @manifest = manifest
      @permission_code = permission_code
    end

    def call
      return fisherman_recipients unless permission_code

      admin_recipients
    end

    def self.approvers_for(manifest)
      resolve(manifest:, permission_code: APPROVAL_PERMISSION)
    end

    def self.capture_verifiers_for(manifest)
      resolve(manifest:, permission_code: CAPTURE_VERIFICATION_PERMISSION)
    end

    def self.fishermen_for(manifest) = resolve(manifest:)

    private

    attr_reader :manifest, :permission_code

    def admin_recipients
      User.kept
          .joins(role: :permissions)
          .where(status: "active", roles: { platform_scope: Role::DOFI_OFFICER_PLATFORM })
          .where(permissions: { code: permission_code })
          .distinct
    end

    def fisherman_recipients
      users = active_company_fishermen
              .where("roles.is_default = ? OR roles.is_default_admin = ?", true, true)
              .to_a
      creator = active_company_fishermen.find_by(id: manifest.created_by_id)
      users << creator if creator
      users.uniq
    end

    def active_company_fishermen
      User.kept
          .joins(:role)
          .where(
            status: "active",
            fisherman_status: "active",
            company_profile_id: manifest.company_profile_id,
            roles: { platform_scope: Role::FISHERMAN_PLATFORM }
          )
    end
  end
end
