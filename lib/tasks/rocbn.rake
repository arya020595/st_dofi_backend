namespace :rocbn do
  desc "Read-only diagnostics for the ROCBN registry connection (SELECT and SHOW only; safe in every environment)"
  task check: :environment do
    abort "ROCBN check failed" unless Rocbn::Check.call
  end

  desc "Create sync_rocbn_hotel if missing and upsert the synthetic companies into the Docker MySQL stand-in. " \
       "Refuses unless ROCBN_ALLOW_SEED=yes, the target is a local MySQL and it holds only synthetic rows."
  task seed: :environment do
    Rocbn::Seeding::Runner.call
  rescue Rocbn::Seeding::Guard::Blocked => e
    abort e.message
  end
end
