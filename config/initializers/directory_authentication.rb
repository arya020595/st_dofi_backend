# Staff sign-in against Active Directory (see docs/registration/active-directory-login.md).
Rails.application.config.to_prepare do
  Warden::Strategies.add(:active_directory, Authentication::ActiveDirectoryStrategy)
end

# Reading the config at boot makes a bad AD_MODE or DEPLOY_ENV (including mock on production) fail the boot.
Rails.application.config.after_initialize do
  config = Authentication::DirectoryConfig.current
  if config.mock? && !Rails.env.local?
    Rails.logger.warn("AD_MODE=mock (#{config.deploy_env}): every staff user signs in with AD_MOCK_PASSWORD.")
  end
end
