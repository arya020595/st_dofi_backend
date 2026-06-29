# Bilingual (EN/MS) Locale — Frontend Contract

Locale is always carried as the `Accept-Language` HTTP header. It is **never** part of a JSON
request body, on any endpoint.

## Saving a language preference

```
PATCH /api/v1/profile/locale
Authorization: Bearer <jwt>
Accept-Language: <current session locale>
Content-Type: application/json

{ "locale": "ms" }
```

Only `en` and `ms` are accepted (enforced by a model validation and a DB check constraint on
`users.preferred_locale`).

Success (`200`):

```json
{
  "status": "success",
  "message": "Language preference updated",
  "data": { "preferred_locale": "ms" }
}
```

Invalid value (`422`):

```json
{
  "status": "fail",
  "message": "Validation failed",
  "data": { "preferred_locale": ["is not included in the list"] }
}
```

After a successful response, the frontend should set the new locale as the **global** header for
all subsequent requests, e.g.:

```js
axios.defaults.headers.common["Accept-Language"] = "ms";
```

## Every other request

Send the user's current locale on every request:

```
Accept-Language: ms
```

The backend reads this header in `ApplicationController#set_locale` (a `before_action`), sets
`I18n.locale` for the duration of the request, and Mobility-backed translated columns / validation
messages resolve accordingly. Unrecognized or missing values fall back to the app default (`en`).

## On login

`POST /api/v1/auth/sign_in` and `GET /api/v1/auth/me` both return the user's saved preference at
`data.user.preferred_locale`. The frontend should set the `Accept-Language` header from this value
immediately after login/`me`, with no extra API call needed.

## Key rules

- Locale is an HTTP header, never a JSON body key.
- Only `en` and `ms` are valid.
- The header affects translated fields, validation/error messages, and any other locale-aware
  response content for that request only — it is not persisted unless sent via
  `PATCH /api/v1/profile/locale`.
