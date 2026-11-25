# Grant access with policies

A new service account has no permissions. It gets permissions from the groups that it is a member of. Each group has policies. A policy allows (`ALLOW`) or denies (`DENY`) actions on the entities whose attributes match its conditions. `DENY` always wins over `ALLOW`.

## In the Massdriver UI

1. Go to the [**Groups**](https://app.massdriver.cloud/orgs?destination=/settings/groups) tab in your organization settings.
2. Create a group for the job, such as `Environment automation`.
3. Add policies to the group. Each policy has an effect, a list of actions, and conditions.
4. Add the service account to the group.

## With Terraform

```hcl
resource "massdriver_group" "environment_automation" {
  name        = "Environment automation"
  description = "Creates and deploys preview environments"
}

resource "massdriver_group_policy" "preview_environments" {
  group_id   = massdriver_group.environment_automation.id
  effect     = "ALLOW"
  actions    = ["project:view", "environment:create", "environment:deploy", "environment:decommission"]
  conditions = jsonencode({ "md-project" = ["api"] })
}

resource "massdriver_service_account_group_membership" "automation" {
  group_id           = massdriver_group.environment_automation.id
  service_account_id = massdriver_service_account.automation.id
}
```

## Choose the actions

Give only the actions that the bundle uses. Some common sets:

| The bundle | Actions |
|---|---|
| Creates preview environments in one project | `project:view`, `environment:create`, `environment:deploy`, `environment:decommission`, `environment:delete` |
| Deploys instances | `project:view`, `instance:configure`, `instance:deploy` |
| Publishes bundles and resource types | `repo:view`, `repo:create`, `repo:push` |
| Manages event destinations | `organization:manageEventDestinations` |

Use conditions to limit a policy to some entities, such as `{"md-project": ["api"]}` or `{"md-environment": ["staging"]}`. A policy with the condition `"*"` matches all entities. Use `"*"` with care, mostly with `DENY`.

Refer to [Access control](https://docs.massdriver.cloud/platform-operations/security/access-control) for the list of actions and attributes.
