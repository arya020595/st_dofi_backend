# The accounts and sign-in helper shared by the Active Directory sign-in integration tests.
module DirectoryAccountsSupport
  LOCAL_PASSWORD = "Password123!".freeze

  def create_directory_accounts
    permission = create(:permission, code: "manifests.view", name: "Manifest List - View")
    @staff = create(:user, :officer_shaped, role: create(:role, kind: Role::DOFI_OFFICER, permissions: [permission]),
                                            username: "mprt/azri.nizam", password: LOCAL_PASSWORD)
    @fisherman = create(:user, :fins_governed_fisherman, username: "mprt/fisherman.one", password: LOCAL_PASSWORD)
    @jetty = create(:user, :jetty_manager_shaped, role: create(:role, kind: Role::JETTY_MANAGER),
                                                  username: "mprt/jetty.manager", password: LOCAL_PASSWORD)
  end

  # Returns the HTTP status so a test can compare several attempts at once.
  def sign_in_as(username, password)
    post "/api/v1/auth/sign_in", params: { user: { username:, password: } }, as: :json
    response.status
  end
end
