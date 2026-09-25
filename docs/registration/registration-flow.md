# BruneiID Account Provisioning and Login

Fisherman and Jetty Manager public registration has been removed. Accounts are provisioned by an
authorized internal workflow before their first BruneiID login.

- Company Profiling provisions Fisherman Owner and optional Admin accounts directly as `active`.
- User Management → External Users creates Jetty Manager accounts directly as `active`.
- `POST /api/v1/auth/brunei_id` remains the simulation endpoint.
- `POST /api/v1/auth/brunei_id/callback` remains the BruneiID OIDC callback endpoint and requires
  `audience: "fisherman"` or `audience: "jetty_manager"`.

Both endpoints issue an application token only for a matching active account. An unknown, inactive,
or audience-mismatched account receives `401 Unauthorized` with a generic message.

There is no registration-status endpoint, public Jetty Manager registration endpoint, FINS Approval
queue, approval remark, claim flow, or registration redirect.
