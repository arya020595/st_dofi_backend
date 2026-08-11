require "test_helper"

module BruneiId
  # rubocop:disable Metrics/ClassLength
  class OidcCallbackTest < ActiveSupport::TestCase
    test "call exchanges code, validates id token, and returns icnumber claim" do
      service = OidcCallback.new
      discovery = {
        "token_endpoint" => "https://brunei.test/token",
        "jwks_uri" => "https://brunei.test/jwks",
        "issuer" => "https://brunei.test",
        "id_token_signing_alg_values_supported" => ["RS256"]
      }
      token_response = { "id_token" => "signed-id-token" }
      claims = { "icnumber" => "01-1234567", "nonce" => "nonce-1" }

      with_env_fetch_stub do
        stub_instance_method(service, :fetch_discovery_document, discovery) do
          stub_instance_method(service, :exchange_code, token_response) do
            stub_instance_method(service, :fetched_jwks, { "keys" => [] }) do
              stub_singleton_method(JWT, :decode, [claims, {}]) do
                result = service.call(
                  code: "opaque-code",
                  code_verifier: "verifier",
                  redirect_uri: "http://217.217.252.45:4100/general/auth/brunei-id/callback",
                  nonce: "nonce-1"
                )

                assert_equal "01-1234567", result.value!
              end
            end
          end
        end
      end
    end

    test "call returns token validation failure when nonce does not match" do
      service = OidcCallback.new
      discovery = {
        "token_endpoint" => "https://brunei.test/token",
        "jwks_uri" => "https://brunei.test/jwks",
        "issuer" => "https://brunei.test"
      }
      token_response = { "id_token" => "signed-id-token" }
      claims = { "icnumber" => "01-1234567", "nonce" => "unexpected" }

      with_env_fetch_stub do
        stub_instance_method(service, :fetch_discovery_document, discovery) do
          stub_instance_method(service, :exchange_code, token_response) do
            stub_instance_method(service, :fetched_jwks, { "keys" => [] }) do
              stub_singleton_method(JWT, :decode, [claims, {}]) do
                result = service.call(
                  code: "opaque-code",
                  code_verifier: "verifier",
                  redirect_uri: "http://217.217.252.45:4100/general/auth/brunei-id/callback",
                  nonce: "nonce-1"
                )

                assert_equal "token_validation_failed", result.failure[:code]
              end
            end
          end
        end
      end
    end

    private

    def with_env_fetch_stub(&)
      stub_singleton_method(ENV, :fetch, env_values, &)
    end

    # rubocop:disable Metrics/MethodLength
    def stub_instance_method(target, method_name, return_value)
      original_defined = target.respond_to?(method_name, true)
      original_method = target.method(method_name) if original_defined

      target.define_singleton_method(method_name) do |*args, **kwargs, &inner|
        if return_value.respond_to?(:call)
          return_value.call(*args, **kwargs, &inner)
        else
          return_value
        end
      end
      yield
    ensure
      target.singleton_class.send(:remove_method, method_name)
      if original_defined
        target.define_singleton_method(method_name) do |*args, **kwargs, &inner|
          original_method.call(*args, **kwargs, &inner)
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    def stub_singleton_method(target, method_name, return_value)
      singleton = target.singleton_class
      original_defined = singleton.method_defined?(method_name) || singleton.private_method_defined?(method_name)
      original_method = singleton.instance_method(method_name) if original_defined

      singleton.send(:define_method, method_name) do |*args, **kwargs, &inner|
        if return_value.respond_to?(:call)
          return_value.call(*args, **kwargs, &inner)
        else
          return_value
        end
      end
      yield
    ensure
      singleton.send(:remove_method, method_name)
      singleton.send(:define_method, method_name, original_method) if original_defined
    end
    # rubocop:enable Metrics/MethodLength

    def env_values
      lambda do |key, _default = nil|
        {
          "BRUNEIID_BASE_URL" => "https://brunei.test",
          "BRUNEIID_CLIENT_ID" => "client-id",
          "BRUNEIID_CLIENT_SECRET" => "client-secret",
          "BRUNEIID_REDIRECT_URI" => "http://217.217.252.45:4100/general/auth/brunei-id/callback"
        }[key]
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
