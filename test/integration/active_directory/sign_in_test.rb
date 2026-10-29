require "test_helper"

module ActiveDirectory
  # POST /api/v1/auth/sign_in with AD_MODE=ldap: the Rails app talks LDAPS to a local simulator (see
  # ActiveDirectoryE2eSupport), so the real strategy, OfficerLogin, LdapAuthenticator and net-ldap are all in play.
  # Proves our side of the protocol only; it says nothing about the client's real directory.
  class SignInTest < ActionDispatch::IntegrationTest
    include ActiveDirectoryE2eSupport

    setup do
      @users_before = User.count
      create_staff("inactive.one", status: "inactive")
      create_staff("suspended.one", status: "suspended")
      create_staff("discarded.one", discarded_at: Time.current)
      create_staff("disabled.one")
    end

    # --- A. valid officer -------------------------------------------------------------------------------------

    test "a valid officer gets the existing sign-in response and a JWT that works, for either bind format" do
      %w[netbios upn].each do |format|
        start_directory(bind_formats: [format.to_sym])

        with_ad(ad_bind_format: format) do
          ad_sign_in("MPRT\\Azri.Nizam")

          assert_response :success, format
          assert_equal %w[access_token user], response.parsed_body["data"].keys.first(2).sort, format
          get "/api/v1/auth/me", headers: bearer

          assert_response :success, format
        end
        assert_equal [{ "netbios" => "MPRT\\azri.nizam", "upn" => "azri.nizam@MPRT.EG.GOV.BN" }[format], [PASSWORD]],
                     [@directory.identities.sole, @directory.binds], format
        @directory.close
      end
    end

    test "the bind name comes from the stored username, whatever was typed" do
      start_directory

      with_ad do
        ["azri.nizam", "AZRI.NIZAM", "mprt/azri.nizam", " MPRT\\azri.nizam "].each { assert_equal 200, ad_sign_in(it) }
      end

      assert_equal ["MPRT\\azri.nizam"], @directory.identities.uniq
    end

    test "a bind format the directory does not accept is a refusal, not an outage" do
      start_directory(bind_formats: [:upn])

      with_ad(ad_bind_format: "netbios") { assert_equal 401, ad_sign_in("azri.nizam") }
    end

    # --- B. wrong password ------------------------------------------------------------------------------------

    test "a wrong AD password is refused once, with no token and no fall back to a local password" do
      start_directory

      with_ad do
        assert_equal 401, ad_sign_in("azri.nizam", "wrong")
        assert_no_token
        assert_equal 401, ad_sign_in("azri.nizam", LOCAL_PASSWORD) # the user row does carry this local password
      end

      assert_equal ["wrong", LOCAL_PASSWORD], @directory.binds
    end

    # --- C. unknown officer -----------------------------------------------------------------------------------

    test "an account only the directory knows is refused, creates nothing and never reaches the directory" do
      start_directory

      with_ad { assert_equal 401, ad_sign_in("ghost.user") }

      assert_no_token
      assert_equal [@users_before + 4, 0], [User.count, @directory.accepted]
    end

    test "unknown user, wrong password and disabled AD account answer identically" do
      start_directory

      with_ad do
        bodies = [["nobody", PASSWORD], ["azri.nizam", "wrong"], ["disabled.one", PASSWORD]].map do |name, password|
          ad_sign_in(name, password)
          [response.status, response.parsed_body]
        end

        assert_equal [bodies.first] * 3, bodies
      end
    end

    # --- D. local eligibility ---------------------------------------------------------------------------------

    test "valid AD credentials cannot override an inactive, suspended or discarded local account" do
      start_directory

      with_ad do
        %w[inactive.one suspended.one discarded.one].each do |name|
          assert_equal 401, ad_sign_in(name), name
          assert_no_token
        end
      end

      assert_empty @directory.binds
    end

    # --- E. disabled or locked in AD --------------------------------------------------------------------------

    test "an account the directory rejects (disabled or locked) is refused: AD was asked, no fall back" do
      start_directory

      with_ad do
        assert_equal 401, ad_sign_in("disabled.one")
        assert_no_token
      end

      assert_equal [PASSWORD], @directory.binds
    end

    # --- L. hostile input and rate limiting -------------------------------------------------------------------

    test "empty, missing, null-byte and oversized credentials are refused without reaching the directory" do
      start_directory
      attempts = [["azri.nizam", ""], ["azri.nizam", nil], ["azri.nizam", "a\0b"], ["azri.nizam", "x" * 257],
                  [nil, PASSWORD], ["", PASSWORD], ["azri\0.nizam", PASSWORD], ["x" * 300, PASSWORD]]

      with_ad do
        attempts.each { |username, password| assert_equal 401, ad_sign_in(username, password), [username, password] }
        post "/api/v1/auth/sign_in", params: { user: "not-a-hash" }, as: :json

        assert_response :unauthorized
        post "/api/v1/auth/sign_in", params: {}, as: :json

        assert_response :unauthorized
      end

      assert_equal 0, @directory.accepted
    end

    test "sign-in attempts are throttled per IP (429) before they reach the directory" do
      start_directory
      store = Rack::Attack.cache.store
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

      with_ad do
        statuses = Array.new(11) { ad_sign_in("azri.nizam", "wrong") }

        assert_equal ([401] * 10) + [429], statuses
      end
      assert_equal 10, @directory.binds.size
    ensure
      Rack::Attack.cache.store = store
    end

    test "the password appears nowhere in the logs, and the parameter filter would mask it anyway" do
      start_directory

      log = capture_logs { with_ad { ad_sign_in("azri.nizam", PASSWORD) } }
      filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
                                               .filter(user: { username: "azri.nizam", password: PASSWORD })

      assert_not_includes log, PASSWORD
      assert_equal %w[ad.login], logged_events(log).pluck("event")
      assert_equal "[FILTERED]", filtered.dig(:user, :password)
    end

    private

    def assert_no_token
      assert_not token_issued?
      assert_nil response.parsed_body.dig("data", "access_token")
    end
  end
end
