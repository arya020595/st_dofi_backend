Permission::Catalog::PERSISTED_ENTRIES.each do |entry|
  permission = Permission.find_or_initialize_by(code: entry.fetch(:code))
  permission.assign_attributes(entry.slice(:name, :platform_scope))
  permission.save! if permission.new_record? || permission.changed?
end

puts "Seeded #{Permission::Catalog::PERSISTED_ENTRIES.size} canonical permissions"
