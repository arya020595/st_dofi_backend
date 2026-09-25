# External Account Provisioning

## Account sources

| Account | Provisioned by | Initial status | Login |
| --- | --- | --- | --- |
| DoFi Officer | Internal User Management | `active` | username/password |
| Jetty Manager | User Management → External Users | `active` | BruneiID |
| Fisherman Owner/Admin | Company Profiling | `active` | BruneiID |
| Fisherman company user | Fisherman User Management | requested `active` or `inactive` state | BruneiID |

## BruneiID

The simulation endpoint and OIDC callback are retained for both Fisherman and Jetty Manager. They
resolve a user by normalized IC number within the requested audience and return an application token
only when that user is active. All unavailable accounts return a generic `401 Unauthorized` response.

There is no public registration, status-check endpoint, FINS Approval queue, approval remark, or
claim-after-approval lifecycle.

## Account lifecycle

External accounts use only `active` and `inactive` operational states. DoFi Officers can deactivate
or reactivate Fisherman and Jetty Manager accounts through External Users. A deactivated account can
no longer receive a BruneiID application token.
