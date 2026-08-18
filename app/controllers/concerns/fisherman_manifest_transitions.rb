module FishermanManifestTransitions
  extend ActiveSupport::Concern
  include Dry::Monads[:result]

  TRANSITION_ACTIONS = %i[submit_port_out resubmit_port_out submit_port_in resubmit_port_in
                          skip_capture_report].freeze

  def submit_port_out
    authorize @manifest
    render_transition(::Manifests::SubmitPortOut.call(@manifest, actor: current_user))
  end

  def resubmit_port_out
    authorize @manifest
    render_transition(::Manifests::ResubmitPortOut.call(@manifest, actor: current_user))
  end

  def submit_port_in
    authorize @manifest
    render_transition(::Manifests::SubmitPortIn.call(@manifest, actor: current_user))
  end

  def resubmit_port_in
    authorize @manifest
    render_transition(::Manifests::ResubmitPortIn.call(@manifest, actor: current_user))
  end

  def skip_capture_report
    authorize @manifest
    result = ::Manifests::SkipCaptureReport.call(@manifest, skip_reason_id: skip_params[:skip_reason_id],
                                                            remarks: skip_params[:skip_reason_remarks],
                                                            actor: current_user)
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
