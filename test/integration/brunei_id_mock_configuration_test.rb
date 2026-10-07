require "test_helper"
require "open3"

class BruneiIdMockConfigurationTest < ActiveSupport::TestCase
  BOOT_PROBE = <<~RUBY.freeze
    require_relative "config/boot"
    require "rails/all"
    Bundler.require(*Rails.groups)
    Dotenv::Rails.load
    Dotenv::Rails.files = ["/dev/null"]
    value = ENV.fetch("MOCK_FLAG_TEST_VALUE")
    value == "__missing__" ? ENV.delete("BRUNEIID_MOCK_ENABLED") : ENV["BRUNEIID_MOCK_ENABLED"] = value
    require_relative "config/environment"
    enabled = Rails.configuration.x.brunei_id_mock_enabled
    actions = Rails.application.routes.routes.filter_map do |route|
      route.defaults[:action] if route.defaults[:controller] == "api/v1/brunei_id_sessions"
    end
    ENV["BRUNEIID_MOCK_ENABLED"] = enabled ? "false" : "true"
    puts({ enabled: enabled, mock_route: actions.include?("create"), callback_route: actions.include?("callback"),
           unchanged_after_env_edit: Rails.configuration.x.brunei_id_mock_enabled == enabled }.to_json)
  RUBY

  test "only explicit true enables the mock route and environment edits take effect on the next boot" do
    %w[true false invalid __missing__].each do |value|
      stdout, stderr, status = Open3.capture3({ "RAILS_ENV" => "test", "MOCK_FLAG_TEST_VALUE" => value },
                                              RbConfig.ruby, "-e", BOOT_PROBE, chdir: Rails.root)

      assert_predicate status, :success?, stderr
      assert_equal({ "enabled" => value == "true", "mock_route" => value == "true", "callback_route" => true,
                     "unchanged_after_env_edit" => true }, JSON.parse(stdout.lines.last))
    end
  end
end
