require "test_helper"

module ActiveDirectory
  # The directory is unreachable, slow, or presents a certificate we must not trust; and the failover between several
  # directory servers. Every case is a 503 (or 401 for a refusal) with no token, no local fall back and nothing
  # sensitive in the log.
  class FailureModesTest < ActionDispatch::IntegrationTest
    include ActiveDirectoryE2eSupport

    UNAVAILABLE = { "status" => "fail", "message" => I18n.t("errors.directory_unavailable") }.freeze

    # --- F. the directory is unavailable ---------------------------------------------------------------------

    test "with the directory stopped staff get a 503 with no local fall back, and the rest of the API works" do
      start_directory
      port = @directory.port
      @directory.close

      with_directory_config(directory_config(ad_host: "localhost", ad_port: port.to_s, ad_ca_file: @ca_file)) do
        ad_sign_in("azri.nizam")

        assert_unavailable
        ad_sign_in("azri.nizam", LOCAL_PASSWORD) # the user row has this local password; it must not be consulted

        assert_unavailable
        get "/up"

        assert_response :success
        assert_equal 200, sign_in_as(@fisherman.username, LOCAL_PASSWORD)
      end
    end

    test "a server that never answers the bind, or hangs up, ends within the configured timeouts" do
      start_directory(script: %i[silent hang_up])

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      with_ad do
        2.times do
          ad_sign_in("azri.nizam")

          assert_unavailable
        end
      end

      assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 6
    end

    # --- G. the certificate is refused ------------------------------------------------------------------------

    {
      "an untrusted CA" => [{}, :other_ca, "untrusted_certificate"],
      "an expired certificate" => [{ expired: true }, :ca, "certificate_expired"],
      "a certificate for another host name" => [{ dns: "another-host.example" }, :ca, "hostname_mismatch"],
      "no CA file, so the system store, which does not hold the test CA" => [{}, :none, "untrusted_certificate"]
    }.each do |label, (directory_options, trust, category)|
      test "#{label} is refused: 503, no bind, the category is logged and nothing sensitive" do
        start_directory(**directory_options)
        other_ca = write_pem(@tmp, "other.pem", issue_certificate("CN=Someone Else", authority: true).last)
        ca_file = { ca: @ca_file, other_ca: other_ca, none: nil }.fetch(trust)

        log = capture_logs { with_ad(ca_file:) { ad_sign_in("azri.nizam") } }

        assert_unavailable
        assert_empty @directory.binds
        assert_equal category, unavailable_event(log)["params"]["tls"]
        assert_empty log.scan(/#{Regexp.union(PASSWORD, '127.0.0.1', 'certificate verify failed', 'does not match')}/)
      end
    end

    test "an explicit CA file that is not a certificate is refused without connecting or using the system store" do
      start_directory
      garbage = File.join(@tmp, "garbage.pem").tap { File.write(it, "not a certificate") }

      log = capture_logs { with_ad(ca_file: garbage) { ad_sign_in("azri.nizam") } }

      assert_unavailable
      assert_equal [0, "misconfigured"], [@directory.accepted, unavailable_event(log).dig("params", "reason")]
    end

    # --- H. failover ------------------------------------------------------------------------------------------

    test "a first server whose certificate is refused fails over to the next, and only the next sees the bind" do
      start_directory(script: [:wrong_certificate])

      with_ad(host: "localhost,localhost") { assert_equal 200, ad_sign_in("azri.nizam") }

      assert_equal [2, [PASSWORD]], [@directory.accepted, @directory.binds]
    end

    test "a server that hangs up fails over to the next" do
      start_directory(script: [:hang_up])

      with_ad(host: "localhost,localhost") { assert_equal 200, ad_sign_in("azri.nizam") }

      assert_equal [2, [PASSWORD]], [@directory.accepted, @directory.binds]
    end

    test "invalid credentials are never replayed on the other servers" do
      start_directory
      create_staff("disabled.one")

      with_ad(host: "localhost,localhost,localhost") do
        assert_equal 401, ad_sign_in("azri.nizam", "wrong")
        assert_equal 401, ad_sign_in("disabled.one")
      end

      assert_equal [2, ["wrong", PASSWORD]], [@directory.accepted, @directory.binds]
    end

    private

    def assert_unavailable
      assert_response :service_unavailable
      assert_equal UNAVAILABLE, response.parsed_body
      assert_not token_issued?
    end

    def unavailable_event(log) = logged_events(log).find { it["event"] == "ad.directory_unavailable" }
  end
end
