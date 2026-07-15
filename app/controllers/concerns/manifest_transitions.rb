module ManifestTransitions
  extend ActiveSupport::Concern

  TRANSITION_ACTIONS = %i[submit_port_out approve_port_out request_amendment_port_out resubmit_port_out
                           submit_port_in approve_port_in request_amendment_port_in resubmit_port_in
                           skip_capture_report].freeze

  def submit_port_out
    authorize @manifest
    render_transition(::Manifests::SubmitPortOut.call(@manifest, actor: current_user))
  end

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

  def resubmit_port_out
    authorize @manifest
    render_transition(::Manifests::ResubmitPortOut.call(@manifest, actor: current_user))
  end

  def submit_port_in
    authorize @manifest
    render_transition(::Manifests::SubmitPortIn.call(@manifest, actor: current_user))
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

  def resubmit_port_in
    authorize @manifest
    render_transition(::Manifests::ResubmitPortIn.call(@manifest, actor: current_user))
  end

  def skip_capture_report
    authorize @manifest
    result = ::Manifests::SkipCaptureReport.call(@manifest, skip_reason_id: skip_params[:skip_reason_id],
                                                            remarks: skip_params[:skip_reason_remarks])
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

  def skip_params
    params.expect(manifest: %i[skip_reason_id skip_reason_remarks])
  end
end
