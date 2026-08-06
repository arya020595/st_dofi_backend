class CaptureReportReviewedByBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :username, :email, :unit, :position
end
