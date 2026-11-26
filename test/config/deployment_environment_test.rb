require "test_helper"

# The deployment files are what keeps mock AD off production: each compose file names its deployment (DEPLOY_ENV),
# and the app refuses to boot with AD_MODE=mock when that is production. These pin the files, so an edit that
# weakens it fails here.
class DeploymentEnvironmentTest < ActiveSupport::TestCase
  RAILS_SERVICES = %w[api jobs].freeze
  COMMITTED_FILES = "{.env.example,docker-compose*.yml,README.md,deploy/**/*,docs/**/*.md,config/**/*,app/**/*," \
                    "db/**/*.rb}".freeze

  def compose_env(path, service)
    compose = YAML.load_file(Rails.root.join(path), aliases: true)
    environment = compose.fetch("services").fetch(service).fetch("environment", {})
    environment.is_a?(Hash) ? environment : environment.to_h { it.split("=", 2) }
  end

  {
    "docker-compose.staging.yml" => "staging",
    "docker-compose.production.yml" => "production",
    "deploy/production/backend/docker-compose.yml" => "production",
    "docker-compose.production.local.yml" => "development"
  }.each do |path, deploy_env|
    test "#{path} runs its Rails services as DEPLOY_ENV=#{deploy_env}" do
      assert_equal([deploy_env] * 2, RAILS_SERVICES.map { |service| compose_env(path, service)["DEPLOY_ENV"] })
    end
  end

  test "the production env example uses the real directory and carries no mock password" do
    example = Rails.root.join("deploy/production/backend/.env.example").read

    assert_equal [true, false], [example.match?(/^AD_MODE=ldap$/), example.match?(/^\s*AD_MOCK_PASSWORD\s*=/)]
  end

  # A developer's own .env (not committed) is expected to set it, so only the committed files are checked.
  test "nothing committed outside the tests assigns a mock password" do
    files = Rails.root.glob(COMMITTED_FILES, File::FNM_DOTMATCH).select(&:file?)
    assignment = /^\s*AD_MOCK_PASSWORD\s*[=:]\s*\S/
    committed = files.select { |file| File.foreach(file, encoding: "UTF-8", invalid: :replace).any?(assignment) }

    assert_empty committed
  end
end
