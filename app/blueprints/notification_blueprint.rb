class NotificationBlueprint < Blueprinter::Base
  identifier :id

  fields :notification_type, :title, :message, :resource_type, :resource_id, :metadata, :read_at, :created_at,
         :updated_at
end
