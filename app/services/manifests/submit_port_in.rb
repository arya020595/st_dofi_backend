module Manifests
  class SubmitPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      return not_ready(manifest) unless manifest.capture_report_ready?
      return Failure(manifest) unless manifest.may_submit_port_in?

      manifest.submit_port_in!(actor: actor)
      Success(manifest)
    end

    private

    def not_ready(manifest)
      manifest.errors.add(:base, "Capture report must be submitted or skipped before requesting port-in")
      Failure(manifest)
    end
  end
end
