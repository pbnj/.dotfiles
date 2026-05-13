# Scalr CLI — Full Command Reference

Generated from `scalr -help`. Load this file when the user asks about a specific
command or category not covered in SKILL.md.

## Access Policy

| Command                | Description             |
| ---------------------- | ----------------------- |
| `create-access-policy` | Create an Access Policy |
| `delete-access-policy` | Delete Access Policy    |
| `get-access-policies`  | List Access Policies    |
| `get-access-policy`    | Get an Access Policy    |
| `update-access-policy` | Update an Access Policy |

## Access Token

| Command                         | Description                       |
| ------------------------------- | --------------------------------- |
| `create-access-token`           | Create an Access Token            |
| `create-agent-pool-token`       | Create an Agent Pool Access Token |
| `delete-access-token`           | Delete an Access Token            |
| `get-access-token`              | Get an Access Token               |
| `list-agent-pool-access-tokens` | List Agent Pool Access Tokens     |
| `update-access-token`           | Update an Access Token            |

## Account

| Command          | Description    |
| ---------------- | -------------- |
| `get-account`    | Get an Account |
| `update-account` | Update Account |

## Account Blob Settings

| Command                         | Description           |
| ------------------------------- | --------------------- |
| `delete-account-blob-settings`  | Delete Blob Settings  |
| `get-account-blob-settings`     | Get Blob Settings     |
| `replace-account-blob-settings` | Replace Blob Settings |
| `update-account-blob-settings`  | Update Blob Settings  |

## Agent

| Command        | Description     |
| -------------- | --------------- |
| `delete-agent` | Delete an Agent |
| `get-agent`    | Get an Agent    |
| `get-agents`   | List Agents     |

## Agent Pool

| Command             | Description          |
| ------------------- | -------------------- |
| `create-agent-pool` | Create an Agent Pool |
| `delete-agent-pool` | Delete an Agent Pool |
| `get-agent-pool`    | Get an Agent Pool    |
| `get-agent-pools`   | List Agent Pools     |
| `update-agent-pool` | Update an Agent Pool |

## Apply

| Command         | Description  |
| --------------- | ------------ |
| `get-apply`     | Get an Apply |
| `get-apply-log` | Apply Log    |

## Configuration Version

| Command                          | Description                    |
| -------------------------------- | ------------------------------ |
| `create-configuration-version`   | Create a Configuration Version |
| `download-configuration-version` | Download Configuration Version |
| `get-configuration-version`      | Get a Configuration Version    |
| `get-configuration-versions`     | List Configuration Versions    |

## Cost Estimate

| Command                       | Description                |
| ----------------------------- | -------------------------- |
| `get-cost-estimate`           | Get a Cost Estimate        |
| `get-cost-estimate-breakdown` | Cost breakdown JSON output |
| `get-cost-estimate-log`       | Cost Estimate log          |

## Endpoint

| Command           | Description        |
| ----------------- | ------------------ |
| `create-endpoint` | Create an Endpoint |
| `delete-endpoint` | Delete an Endpoint |
| `get-endpoint`    | Get an Endpoint    |
| `list-endpoints`  | List Endpoints     |
| `update-endpoint` | Update Endpoint    |

## Environment

| Command              | Description           |
| -------------------- | --------------------- |
| `create-environment` | Create an Environment |
| `delete-environment` | Delete an Environment |
| `get-environment`    | Get an Environment    |
| `list-environments`  | List Environments     |
| `update-environment` | Update Environment    |

## Event Definition

| Command                  | Description            |
| ------------------------ | ---------------------- |
| `list-event-definitions` | List Event Definitions |

## Module

| Command                 | Description             |
| ----------------------- | ----------------------- |
| `create-module`         | Publish a Module        |
| `delete-module`         | Unpublish a Module      |
| `get-module`            | Get a Module            |
| `list-modules`          | List Modules            |
| `resync-module`         | Resync a Module         |
| `resync-module-version` | Resync a Module Version |

## Module Version

| Command                | Description          |
| ---------------------- | -------------------- |
| `get-module-version`   | Get a Module Version |
| `list-module-versions` | List Module Versions |

## Permission

| Command           | Description      |
| ----------------- | ---------------- |
| `get-permission`  | Get a Permission |
| `get-permissions` | List Permissions |

## Ping

| Command | Description |
| ------- | ----------- |
| `ping`  | Ping        |

## Plan

| Command                     | Description           |
| --------------------------- | --------------------- |
| `get-json-output`           | JSON Output           |
| `get-plan`                  | Get a Plan            |
| `get-plan-log`              | Plan Log              |
| `get-sanitized-json-output` | Sanitized JSON Output |

## Policy

| Command      | Description  |
| ------------ | ------------ |
| `get-policy` | Get a Policy |

## Policy Check

| Command                 | Description        |
| ----------------------- | ------------------ |
| `get-policy-check`      | Get a Policy Check |
| `get-policy-checks-log` | Policy Check Log   |
| `list-policy-checks`    | List Policy Checks |
| `override-policy`       | Override Policy    |

## Policy Group

| Command                            | Description                                    |
| ---------------------------------- | ---------------------------------------------- |
| `create-policy-group`              | Create a Policy Group                          |
| `create-policy-group-environments` | Create policy group environments relationships |
| `delete-policy-group`              | Delete a Policy Group                          |
| `delete-policy-group-environments` | Delete policy group's environment relationship |
| `get-policy-group`                 | Get a Policy Group                             |
| `list-policy-groups`               | List Policy Groups                             |
| `update-policy-group`              | Update a Policy Group                          |
| `update-policy-group-environments` | Update policy group environments relationships |

## Provider Configuration

| Command                         | Description                     |
| ------------------------------- | ------------------------------- |
| `create-provider-configuration` | Create a Provider configuration |
| `delete-provider-configuration` | Delete a Provider configuration |
| `get-provider-configuration`    | Get a Provider configuration    |
| `list-provider-configurations`  | List Provider configurations    |
| `update-provider-configuration` | Update a Provider configuration |

## Provider Configuration Link

| Command                                        | Description                                      |
| ---------------------------------------------- | ------------------------------------------------ |
| `create-provider-configuration-link`           | Attach a Provider configuration to the workspace |
| `delete-provider-configuration-workspace-link` | Delete a Provider configuration workspace link   |
| `get-provider-configuration-link`              | Get a Provider configuration link                |
| `list-provider-configuration-links`            | List Provider configuration workspace links      |
| `update-provider-configuration-link`           | Update a Provider configuration link             |

## Provider Configuration Parameter

| Command                                   | Description                               |
| ----------------------------------------- | ----------------------------------------- |
| `create-provider-configuration-parameter` | Create a Provider configuration parameter |
| `delete-provider-configuration-parameter` | Delete a Provider configuration parameter |
| `get-provider-configuration-parameter`    | Get a Provider configuration parameter    |
| `list-provider-configuration-parameters`  | List Provider configuration parameters    |
| `update-provider-configuration-parameter` | Update a Provider configuration parameter |

## Role

| Command       | Description   |
| ------------- | ------------- |
| `create-role` | Create a Role |
| `delete-role` | Delete a Role |
| `get-role`    | Get a Role    |
| `get-roles`   | List Roles    |
| `update-role` | Update a Role |

## Run

| Command                 | Description             |
| ----------------------- | ----------------------- |
| `cancel-run`            | Cancel a Run            |
| `confirm-run`           | Apply a Run             |
| `create-run`            | Create a Run            |
| `discard-run`           | Discard a Run           |
| `download-policy-input` | Download a Policy Input |
| `get-run`               | Get a Run               |
| `get-runs`              | List Runs               |
| `get-runs-queue`        | List Runs Queue         |

## Run Trigger

| Command              | Description          |
| -------------------- | -------------------- |
| `create-run-trigger` | Create a Run Trigger |
| `delete-run-trigger` | Delete a Run Trigger |
| `get-run-trigger`    | Get a Run Trigger    |

## Service Account

| Command                  | Description              |
| ------------------------ | ------------------------ |
| `create-service-account` | Create a Service Account |
| `delete-service-account` | Delete a Service Account |
| `get-service-account`    | Get a Service Account    |
| `get-service-accounts`   | List Service Accounts    |
| `update-service-account` | Update a Service Account |

## State Version

| Command                      | Description                           |
| ---------------------------- | ------------------------------------- |
| `get-current-state-version`  | Get Workspace's Current State Version |
| `get-state-version`          | Get a State Version                   |
| `get-state-version-download` | Download State Version                |
| `list-state-versions`        | List Workspace's State Versions       |

## Tag

| Command      | Description  |
| ------------ | ------------ |
| `create-tag` | Create a Tag |
| `delete-tag` | Delete a Tag |
| `get-tag`    | Get a Tag    |
| `list-tags`  | List Tags    |
| `update-tag` | Update a Tag |

## Team

| Command       | Description   |
| ------------- | ------------- |
| `create-team` | Create a Team |
| `delete-team` | Delete a Team |
| `get-team`    | Get a Team    |
| `get-teams`   | List Teams    |
| `update-team` | Update a Team |

## Usage Statistic

| Command                 | Description                 |
| ----------------------- | --------------------------- |
| `list-usage-statistics` | List Scalr Usage Statistics |

## User

| Command                    | Description                        |
| -------------------------- | ---------------------------------- |
| `create-user`              | Create a User                      |
| `delete-user`              | Delete a User                      |
| `get-account-users`        | List Account to User relationships |
| `get-user`                 | Get a User                         |
| `get-users`                | List Users                         |
| `invite-user-to-account`   | Invite a User to the Account       |
| `remove-user-from-account` | Remove a User from the Account     |
| `update-user`              | Update a User                      |

## Variable

| Command           | Description       |
| ----------------- | ----------------- |
| `create-variable` | Create a Variable |
| `delete-variable` | Delete a Variable |
| `get-variable`    | Get a Variable    |
| `get-variables`   | List Variables    |
| `update-variable` | Update a Variable |

## VCS Provider

| Command               | Description           |
| --------------------- | --------------------- |
| `create-vcs-provider` | Create a VCS Provider |
| `delete-vcs-provider` | Delete a VCS Provider |
| `get-vcs-provider`    | Get a VCS Provider    |
| `list-vcs-providers`  | List VCS Providers    |
| `update-vcs-provider` | Update a VCS Provider |

## Webhook

| Command          | Description      |
| ---------------- | ---------------- |
| `create-webhook` | Create Webhook   |
| `delete-webhook` | Delete a Webhook |
| `get-webhook`    | Get a Webhook    |
| `list-webhooks`  | List Webhooks    |
| `update-webhook` | Update Webhook   |

## Workspace

| Command                          | Description                          |
| -------------------------------- | ------------------------------------ |
| `add-remote-state-consumers`     | Add remote state consumers           |
| `add-workspace-tags`             | Add tags to the workspace            |
| `create-workspace`               | Create a Workspace                   |
| `delete-remote-state-consumers`  | Delete remote state consumers        |
| `delete-workspace`               | Delete a Workspace                   |
| `delete-workspace-tags`          | Delete workspace's tags              |
| `get-workspace`                  | Get a Workspace                      |
| `get-workspaces`                 | List Workspaces                      |
| `list-remote-state-consumers`    | List remote state consumers          |
| `list-workspace-tags`            | List workspace's tags                |
| `lock-workspace`                 | Lock a Workspace                     |
| `replace-remote-state-consumers` | Replace remote state consumers       |
| `replace-workspace-tags`         | Replace workspace's tags             |
| `resync-workspace`               | Resync a Workspace                   |
| `set-schedule`                   | Set scheduled runs for the workspace |
| `unlock-workspace`               | Unlock a Workspace                   |
| `update-workspace`               | Update a Workspace                   |
