require "test_helper"

class CaptureReports::MutationSafetyTest < ActiveSupport::TestCase
  setup do
    @report = create(:capture_report)
    @gear = create(:fishing_gear_detail, capture_report: @report, quantity: 2)
    @fish = create(:fish_capture_detail, capture_report: @report, fishing_gear_detail: @gear)
    @stale_report = CaptureReport.find(@report.id)
    CaptureReports::Verify.call(@report, actor: nil).value!
  end

  test "stale report cannot change verified content" do
    assert_predicate CaptureReports::Update.call(@stale_report, zone_area: "Changed"), :failure?
    assert_nil @report.reload.zone_area
  end

  test "stale report cannot create fish details" do
    result = FishCaptureDetails::Create.call(@stale_report, fish_attributes)

    assert_predicate result, :failure?
    assert_equal 1, @report.fish_capture_details.count
  end

  test "stale report cannot create gear details" do
    assert_predicate FishingGearDetails::Create.call(@stale_report, name: "Changed"), :failure?
    assert_equal 1, @report.fishing_gear_details.count
  end

  test "verified fish details cannot be updated" do
    assert_predicate FishCaptureDetails::Update.call(@fish, amount_captured_kg: 99), :failure?
    assert_equal BigDecimal("5"), @fish.reload.amount_captured_kg
  end

  test "verified gear details cannot be updated" do
    assert_predicate FishingGearDetails::Update.call(@gear, quantity: 99), :failure?
    assert_equal 2, @gear.reload.quantity
  end

  test "verified fish details cannot be destroyed" do
    assert_predicate FishCaptureDetails::Destroy.call(@fish), :failure?
    assert FishCaptureDetail.exists?(@fish.id)
  end

  test "verified gear details cannot be destroyed including their dependent catches" do
    assert_predicate FishingGearDetails::Destroy.call(@gear), :failure?
    assert FishCaptureDetail.exists?(@fish.id)
    assert FishingGearDetail.exists?(@gear.id)
  end

  test "bulk sync retains per-row failures without inserting or updating verified content" do
    new_id = SecureRandom.uuid
    result = FishCaptureDetails::BulkSync.call(@stale_report,
                                               [fish_attributes.merge(id: @fish.id, amount_captured_kg: 99),
                                                fish_attributes.merge(id: new_id)])

    assert_equal %w[fail fail], result.value!.pluck(:status)
    assert_equal [@fish.id, new_id], result.value!.pluck(:id)
    assert_equal [1, BigDecimal("5")], [@report.fish_capture_details.count, @fish.reload.amount_captured_kg]
  end

  test "stale report cannot request amendment after verification" do
    assert_predicate CaptureReports::RequestAmendment.call(@stale_report, actor: nil, remarks: "Changed"), :failure?
    assert_equal "verified", @report.reload.capture_report_status
  end

  private

  def fish_attributes
    { dictionary_id: @fish.dictionary_id, fishing_gear_detail_id: @gear.id,
      price_per_kg: 10, amount_captured_kg: 5 }
  end
end
