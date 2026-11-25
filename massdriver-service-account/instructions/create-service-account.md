# Create a service account

A service account is a non-human identity in your organization. Its access token lets a bundle call the Massdriver API.

## In the Massdriver UI

1. Go to the [**Service Accounts**](https://app.massdriver.cloud/orgs?destination=/settings/service-accounts) page in your organization settings.
2. Click **Add Service Account** and enter a name, such as `platform-automation`.
3. Copy the access token. It starts with `md_`. Massdriver shows it one time only.

To make one more token for a service account, use the `createServiceAccountAccessToken` mutation of the [GraphQL API](https://docs.massdriver.cloud/api/graphql). Revoke the old token after you update the resource.

## With Terraform

The [Massdriver Terraform provider](https://registry.terraform.io/providers/massdriver-cloud/massdriver/latest/docs/resources/service_account) creates the service account and its token:

```hcl
resource "massdriver_service_account" "automation" {
  name                     = "platform-automation"
  description              = "Manages projects and environments"
  token_expiration_minutes = 525600 # 1 year
}
```

The `token` attribute holds the access token. It is sensitive.

## Fill in the resource

| Field | Value | Environment variable |
|---|---|---|
| `url` | `https://api.massdriver.cloud`, or the URL of your self-hosted installation | `MASSDRIVER_URL` |
| `organization_id` | Your organization identifier, such as `acme` | `MASSDRIVER_ORGANIZATION_ID` |
| `api_key` | The access token, `md_...` | `MASSDRIVER_API_KEY` |

To import it with the CLI, put the fields in a JSON file and run:

```bash
mass resource create \
  --name "Platform automation" \
  --type massdriver-service-account \
  --file service-account.json
```

## Use it in a bundle

Give the fields to the Terraform provider:

```hcl
provider "massdriver" {
  url             = var.massdriver.url
  organization_id = var.massdriver.organization_id
  api_key         = var.massdriver.api_key
}
```

Or set the environment variables for the `mass` CLI and the Go SDK:

```bash
export MASSDRIVER_URL="https://api.massdriver.cloud"
export MASSDRIVER_ORGANIZATION_ID="acme"
export MASSDRIVER_API_KEY="md_..."
```

## Security

- The `api_key` field is sensitive. Massdriver masks it in the UI and the API. A person needs `resource:export` to download it.
- A new service account has no permissions. Give it only the permissions that the bundle needs. Refer to **Grant access with policies**.
- Set an expiration on the token, and make a new token before it expires.
