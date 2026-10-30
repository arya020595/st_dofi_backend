require "test_helper"

# The client's browsers cannot reach the file storage server, so files travel FE -> BE -> storage on upload and
# storage -> BE -> FE on download. The only door out is Api::V1::AttachmentsController
# (GET /api/v1/attachments/:signed_id): it authorizes, reads the bytes itself and sends them. Anything that hands a
# browser a storage URL (a presigned or public object URL, Active Storage's own proxy/redirect routes, a direct
# upload) would silently break this in production.
class FilesServedOnlyThroughRelayTest < ActiveSupport::TestCase
  STORAGE_URL_CALL = Regexp.union(
    /\.service_url\b/, /\.service\.url\b/, /\bpresigned_url\b/, /\bdirect_upload/i,
    /\brails_(?:blob|storage|representation|disk_service)\w*_(?:url|path)\b/,
    /\b(?:image|file|blob|attachment|attachments|\w+_image)\.url\b/
  )

  test "no app code builds a storage URL for a browser" do
    offenders = Rails.root.glob("{app,lib}/**/*.rb").flat_map { |file| storage_url_calls(file) }

    assert_empty offenders, "Files must go out through AttachmentsController, never as a storage URL:\n" \
                            "#{offenders.join("\n")}"
  end

  test "production closes Active Storage's own routes (blob proxy/redirect and direct uploads)" do
    assert_match(/^\s*config\.active_storage\.draw_routes\s*=\s*false\b/,
                 Rails.root.join("config/environments/production.rb").read)
  end

  test "every model that attaches files has a policy the relay can authorize with" do
    unauthorizable = attached_model_names.reject do |name|
      Api::V1::AttachmentsController::POLICY_CLASS_BY_RECORD_TYPE.key?(name) || "#{name}Policy".safe_constantize
    end

    assert_empty unauthorizable, "AttachmentsController cannot authorize files of #{unauthorizable.to_sentence}: " \
                                 "add a policy, or map it in POLICY_CLASS_BY_RECORD_TYPE"
  end

  private

  def attached_model_names
    Rails.root.glob("app/models/**/*.rb").filter_map do |file|
      source = file.read
      source[/^class (\w+)/, 1] if source.match?(/has_(?:one|many)_attached/)
    end
  end

  def storage_url_calls(file)
    relative = file.relative_path_from(Rails.root).to_s

    File.readlines(file).each_with_index.filter_map do |line, index|
      next if line.strip.start_with?("#") || !line.match?(STORAGE_URL_CALL)

      "#{relative}:#{index + 1}: #{line.strip}"
    end
  end
end
