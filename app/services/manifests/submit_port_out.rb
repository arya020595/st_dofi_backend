module Manifests
  class SubmitPortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      return Failure(manifest) unless manifest.may_submit_port_out?

      manifest.submit_port_out!(actor: actor)
      Success(manifest)
    end
  end
end
