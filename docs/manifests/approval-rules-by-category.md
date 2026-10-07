# Manifest approval rules by fisherman category

Who has to approve what depends on the manifest's `fisherman_category`. It is derived server-side from
`company_profile.registration_type` in `Manifests::Create` and never accepted from the client.

| Category | Port-Out | Capture Report | Capture Report skipped (with a reason) | Port-In |
|---|---|---|---|---|
| `commercial` | Jetty Manager approves | DoFi Officer verifies independently from Port-In approval | No DoFi verification | Jetty Manager approves independently from Capture Report verification |
| `small_scale_full_time`, `small_scale_part_time`, `small_scale_company` | No approval | DoFi Officer verifies; the manifest then completes | No DoFi verification | No approval; the manifest completes on submit |

Part-Time, Full-Time and Small-Scale (Company) follow identical rules, so they share the `small_scale?` group.

## Where each rule lives

- **Port-Out / Port-In routing** — the `submit_port_out` and `submit_port_in` events in
  [`Manifest::PortOutWorkflow`](../../app/models/concerns/manifest/port_out_workflow.rb) and
  [`Manifest::PortInWorkflow`](../../app/models/concerns/manifest/port_in_workflow.rb). Their guards
  (`commercial?` / `small_scale?`, plus `capture_report_ready?` for Port-In) are the single source of truth.
- **When the manifest moves on** — [`Manifest::Lifecycle`](../../app/models/concerns/manifest/lifecycle.rb).
  Two conditions decide everything: `port_in_settled?` (commercial: Jetty Manager approved; small-scale:
  submitted) and `capture_reports_settled?` (skipped, or every report verified). Both settled means
  `completed`; for a commercial manifest, only the report leg settled means `awaiting_port_in_approval`.
  `Manifest#advance_lifecycle!` fires whatever those guards now allow, and is called after Port-In is
  submitted, approved or resubmitted and after a report is verified — whichever leg finishes last wins.
- **Who is notified** — [`app/services/manifests/submit_port_in.rb`](../../app/services/manifests/submit_port_in.rb):
  capture-report verifiers when there are reports to verify, and Jetty Managers as soon as a commercial
  Port-In is submitted (they never wait for DoFi verification), nobody for a skipped small-scale manifest.
- **A report is either skipped or submitted, never both** — enforced by model validations, so no write
  path can bypass it: [`Manifest::CaptureReportState`](../../app/models/concerns/manifest/capture_report_state.rb) refuses `capture_report_skipped` once
  reports exist, and [`CaptureReport`](../../app/models/capture_report.rb) refuses creation once skipped.

Port-In details (port, area, time) are applied with `Manifests::Update` while the manifest is at sea and its
Port-In is still a draft, for any category. Commercial Port-In approval and Capture Report verification run
in parallel: after either one succeeds, the manifest completes only when both legs are settled (see above).
Until then, `manifest_status` remains `capture_report_submitted` (or `awaiting_port_in_approval` when only
Port-In approval remains). The rules are executable in
[`test/models/manifest_completion_rules_test.rb`](../../test/models/manifest_completion_rules_test.rb).
