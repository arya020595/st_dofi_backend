module ManifestApprovalTransitions
  extend ActiveSupport::Concern
  include Dry::Monads[:result]

  TRANSITION_ACTIONS = %i[approve_port_out request_amendment_port_out approve_port_in
                          request_amendment_port_in].freeze

  def approve_port_out
    authorize @manifest
    render_transition(::Manifests::ApprovePortOut.call(@manifest, actor: current_user))
  end

  def request_amendment_port_out
    authorize @manifest
    result = ::Manifests::RequestAmendmentPortOut.call(@manifest, actor: current_user,
                                                                  remarks: params.expect(:remarks))
    render_transition(result)
  end

  def approve_port_in
    authorize @manifest
    render_transition(::Manifests::ApprovePortIn.call(@manifest, actor: current_user))
  end

  def request_amendment_port_in
    authorize @manifest
    result = ::Manifests::RequestAmendmentPortIn.call(@manifest, actor: current_user,
                                                                 remarks: params.expect(:remarks))
    render_transition(result)
  end

  private

  def render_transition(result)
    case result
    in Success(manifest)
      render json: { status: "success", data: ManifestDetailBlueprint.render_as_hash(manifest) }
    in Failure(manifest)
      render json: { status: "fail", errors: manifest.errors.full_messages }, status: :unprocessable_content
    end
  end
end
