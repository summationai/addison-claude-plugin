# Auth Reference

The skill must use public `sum-api` authentication only.

## Supported Runtime Inputs

Device-login credential:

```bash
SUM_API_DEVICE_LOGIN_CREDENTIAL=sm_dls_...
```

Bearer token:

```bash
SUM_API_ACCESS_TOKEN=...
```

M2M credentials:

```bash
SUM_API_CLIENT_ID=...
SUM_API_CLIENT_SECRET=...
SUM_API_M2M_SCOPE="agent:read agent:write"
```

Base URL:

```bash
SUM_API_BASE_URL=https://sandbox-api.summation.com
```

Local config file:

```text
.summation-config
```

The file uses environment-style lines:

```bash
SUM_API_BASE_URL=https://sandbox-api.summation.com
SUM_API_DEVICE_LOGIN_CREDENTIAL=sm_dls_...
SUM_API_CLIENT_ID=...
SUM_API_CLIENT_SECRET=...
SUM_API_M2M_SCOPE="agent:read agent:write"
```

It also supports named profiles in one file:

```bash
SUM_API_ACTIVE_PROFILE=shared-sandbox

[profile.shared-sandbox]
SUM_API_BASE_URL=https://sandbox-api.summation.com
SUM_API_DEVICE_LOGIN_CREDENTIAL=sm_dls_...
SUM_API_CLIENT_ID=...
SUM_API_CLIENT_SECRET=...
SUM_API_M2M_SCOPE="agent:read agent:write"

[profile.fanatics-prod]
SUM_API_BASE_URL=https://api-fanatics.summation.com
SUM_API_DEVICE_LOGIN_CREDENTIAL=sm_dls_...
SUM_API_CLIENT_ID=...
SUM_API_CLIENT_SECRET=...
SUM_API_M2M_SCOPE="agent:read agent:write"
```

Select a profile with `SUM_API_PROFILE`, `SUMMATION_PROFILE`, `SUM_API_ACTIVE_PROFILE`, or the helper's `--profile` flag. Environment variables still override values from the selected profile.

Useful profile commands:

```bash
python3 scripts/sum_api.py profiles
python3 scripts/sum_api.py use-profile shared-sandbox
python3 scripts/sum_api.py configure --profile fanatics-prod --activate
```

Set `SUM_API_CONFIG_FILE` or `SUMMATION_CONFIG` to point the helper at a specific config file.

The helper reads settings in this order:

1. Environment variables.
2. `SUM_API_CONFIG_FILE`.
3. Current directory `.summation-config`.
4. `~/.summation/skill-config` (canonical).
5. Installed skill directory `.summation-config` (legacy).
6. Home directory `.summation-config` (legacy).

A config found only in a legacy location is copied to `~/.summation/skill-config` on first use; the legacy file is left in place and the canonical path wins afterward.

Use file mode `0600` for files that contain secrets.

## Auth Precedence

The helper resolves auth in this order:

1. `SUM_API_DEVICE_LOGIN_CREDENTIAL`
2. `SUM_API_ACCESS_TOKEN`
3. M2M via `SUM_API_CLIENT_ID` and `SUM_API_CLIENT_SECRET`

## Device Login Flow

Device login is the default interactive auth path for users.

Use the sibling `login` skill for the step-by-step interactive flow. The helper starts login with `login`, stores temporary local polling state (`0600`), completes approval with `login-poll`, and revokes the device-login session plus removes the local credential with `logout`. `login` accepts `--base-url` for environments that are not already configured; `login-poll` uses the stored base URL from the pending login state.

On approval, the helper stores `SUM_API_DEVICE_LOGIN_CREDENTIAL` in `~/.summation/skill-config`. Do not print or quote `device_code` in chat; the helper now keeps it only in temporary local polling state until `login-poll` finishes.

## M2M Flow

When both `SUM_API_DEVICE_LOGIN_CREDENTIAL` and `SUM_API_ACCESS_TOKEN` are absent and M2M credentials are present, exchange the client credentials through:

```text
POST /v1/auth/m2m/token
```

The token exchange is sent as `application/x-www-form-urlencoded`, not JSON. Normal sum-api calls still use JSON bodies.

The returned access token is used as:

```text
Authorization: Bearer <access_token>
```

The client ID and secret are caller-owned inputs. The skill can read them from the local config file, but the installer never writes secrets and the repo ignores `.summation-config`.

## Identity Rules

- The service principal identity is resolved by `sum-api` and auth-service.
- Organization identity must come from trusted token claims and auth-service resolution.
- Do not accept caller-provided `x-org-id`, `x-user-id`, `x-tenant-id`, or similar headers as trusted identity.
- If an operation targets an org or project, verify it is consistent with the authenticated principal by relying on the API response or error.

## Troubleshooting

- `401` usually means missing, expired, or invalid credentials.
- `403` usually means the token is valid but the principal lacks permission.
- `404` can mean the resource does not exist or is not visible to the principal.
- `429` means retry with jitter and respect any retry headers.
- On macOS, `certificate verify failed` usually means Python cannot find a CA bundle. Set `SSL_CERT_FILE` to a CA bundle path or install `certifi` in the Python environment running the skill helper.
