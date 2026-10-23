require "test_helper"

# The registry connection is wired outside database.yml (config/rocbn.yml) so no Rails database task can reach it.
# These tests pin that, and that the production block is read-only and driven by the environment alone.
class RocbnConnectionTest < ActiveSupport::TestCase
  RUNTIME_ENV = { "ROCBN_DB_HOST" => "registry.example.test", "ROCBN_DB_PORT" => "9139",
                  "ROCBN_DB_NAME" => "registry_db", "ROCBN_DB_USERNAME" => "reader",
                  "ROCBN_DB_PASSWORD" => "s3cret" }.freeze
  TEST_ENV = %w[ROCBN_TEST_DB_HOST ROCBN_TEST_DB_PORT ROCBN_TEST_DB_NAME ROCBN_TEST_DB_USERNAME
                ROCBN_TEST_DB_PASSWORD].freeze

  test "no Rails database task can see the registry" do
    %w[development test production].each do |env|
      names = ActiveRecord::Base.configurations.configs_for(env_name: env, include_hidden: true).map(&:name)

      assert_not_includes names, "rocbn", "database.yml must not list the registry (#{env})"
    end
  end

  test "schema annotation does not connect to the optional registry" do
    company_model = Rails.root.join("app/models/rocbn/company.rb").read

    assert_match(/\A# -\*- SkipSchemaAnnotations\b/, company_model)
  end

  test "registry models use the rocbn connection while DoFi models stay on PostgreSQL" do
    assert_equal %w[rocbn trilogy], [Rocbn::Company.connection_db_config.name,
                                     Rocbn::Company.connection_db_config.adapter]
    assert_equal "postgresql", ApplicationRecord.connection_db_config.adapter
  end

  test "production reads its connection from the environment and is read-only" do
    config = with_env(RUNTIME_ENV) { Rails.application.config_for(:rocbn, env: "production") }

    assert_equal ["registry.example.test", 9139, "registry_db", "reader", "s3cret"],
                 config.values_at(:host, :port, :database, :username, :password)
    assert config[:replica]
  end

  test "development is read-only too, and nothing in the file hard-codes the production server" do
    config = with_env(RUNTIME_ENV) { Rails.application.config_for(:rocbn, env: "development") }

    assert config[:replica]
    assert_no_match(/10\.252\.8\.23|9139|stuser/, config_without_comments)
  end

  test "the adapter refuses writes on a read-only config" do
    config = with_env(RUNTIME_ENV) { Rails.application.config_for(:rocbn, env: "production") }

    assert_predicate ActiveRecord::ConnectionAdapters::TrilogyAdapter.new(config.to_h), :preventing_writes?
  end

  test "tests never read the runtime variables, so a test run cannot reach a real registry" do
    config = with_env(RUNTIME_ENV, unset: TEST_ENV) { Rails.application.config_for(:rocbn, env: "test") }

    assert_equal ["127.0.0.1", "tdd_db_test"], config.values_at(:host, :database)
    assert_not config[:replica]
  end

  private

  # The values only: comments may name the production server, the settings may not.
  def config_without_comments
    Rails.root.join("config/rocbn.yml").read.lines.grep_v(/\A\s*#/).join
  end

  def with_env(set, unset: [])
    saved = (set.keys + unset).index_with { |key| ENV.fetch(key, nil) }
    unset.each { |key| ENV.delete(key) }
    set.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
