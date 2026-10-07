# Drives a manifest or capture report through the same services production uses, minus the notifications, so test
# setup follows the real lifecycle (status cascade, amendment snapshot, history). Each call raises if the
# transition isn't allowed. Tests of the bare AASM tables call the model events directly instead.
module LifecycleHelper
  def fire_manifest(manifest, event, **)
    Manifests::Transition.call(manifest, event, **).value!
  end

  def fire_report(report, event, **)
    CaptureReports::Transition.call(report, event, **).value!
  end
end
