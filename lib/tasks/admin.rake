namespace :admin do
  desc "Map an existing staff user to its Active Directory name: EMAIL=admin@dofi.gov.bn AD_USERNAME=mprt/real.name"
  task assign_ad_username: :environment do
    prefix = User::USERNAME_PREFIX
    user = User.kept.find_by(email: ENV["EMAIL"].to_s.strip.downcase)
    abort "No active user with that EMAIL." unless user
    abort "#{user.email} is not DoFi staff, so it does not sign in through AD." unless user.directory_managed?

    short = Authentication::DirectoryUsername.new(ENV.fetch("AD_USERNAME", nil), domain: prefix).short
    abort "AD_USERNAME must be an AD name (letters, digits, '.', '_', '-'), e.g. #{prefix}/azri.nizam." unless short

    username = "#{prefix}/#{short}".downcase
    taken = User.where(username: [short, username]).where.not(id: user.id).exists?
    abort "#{username} (or #{short}) already belongs to another user." if taken

    user.update!(username: username) # a changed username also revokes the user's tokens (User#revoke_tokens)
    puts "#{user.email} now signs in as #{username}."
  end
end
