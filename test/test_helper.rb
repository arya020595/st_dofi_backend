ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# A minimal test double for an Active Storage service, standing in for the real minio_public /
# minio_assets_public S3 services in tests — those would otherwise try to sign against test env's
# blank credentials, which triggers a slow AWS credential-chain fallback (a real network call to
# the EC2 instance-metadata endpoint) before failing outright. Minitest::Mock isn't available in
# this Minitest version (removed from core in 6.x), hence hand-rolled rather than a gem.
class RecordingServiceDouble
  attr_reader :captured_key, :captured_options

  def initialize(return_url) = @return_url = return_url

  def url(key, **options)
    @captured_key = key
    @captured_options = options
    @return_url
  end
end

module ActiveSupport
  class TestCase
    include FactoryBot::Syntax::Methods

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Temporarily makes ActiveStorage::Blob.services.fetch(name) return fake_service instead of
    # looking up the real configured service — see RecordingServiceDouble above.
    def stub_fetched_service(name, fake_service)
      services = ActiveStorage::Blob.services
      original = services.method(:fetch)
      services.define_singleton_method(:fetch) do |requested|
        requested == name ? fake_service : original.call(requested)
      end
      yield
    ensure
      services.singleton_class.send(:remove_method, :fetch)
    end

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  def auth_headers_for(user, password:)
    post "/api/v1/auth/sign_in", params: { user: { username: user.username, password: password } }, as: :json
    { "Authorization" => response.headers["Authorization"] }
  end
end
