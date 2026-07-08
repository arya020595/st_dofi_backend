def unique_officer_username(user)
  base = user.employee_id.presence || user.name.parameterize(separator: ".")
  username = "#{User::USERNAME_PREFIX}/#{base}"
  username = "#{username}-#{SecureRandom.hex(2)}" while User.exists?(username: username.downcase)
  username
end

namespace :users do
  desc "Backfill `username` on officer/admin users left with a nil one because find_or_create_by! " \
       "only sets attributes when creating a record, never on an already-existing match. DRY_RUN=1 to preview."
  task backfill_usernames: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", nil))
    excluded_role_ids = Role.where(reference_id: UserPolicy::EXTERNAL_ROLE_REFERENCE_IDS).select(:id)
    officers = User.kept.where(role_id: nil).or(User.kept.where.not(role_id: excluded_role_ids))
                   .where(username: nil)
    puts "Found #{officers.count} officer/administrator user(s) missing a username#{' (dry run)' if dry_run}."

    officers.find_each do |user|
      username = unique_officer_username(user)
      label = user.email.presence || user.id

      if dry_run
        puts "[dry run] #{label}: username -> #{username}"
        next
      end

      if user.update(username: username)
        puts "Backfilled #{label}: username = #{user.reload.username}"
      else
        puts "Skipped #{label}: #{user.errors.full_messages.join(', ')}"
      end
    end

    puts "Done." unless dry_run
  end
end
