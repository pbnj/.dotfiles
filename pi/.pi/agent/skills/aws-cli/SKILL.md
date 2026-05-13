---
name: aws-cli
description: "Use when interacting with AWS. Triggers on AWS resources, services, or
  accounts — s3, ec2, iam, kms, secretsmanager, eks, ecs, lambda, cloudwatch,
  rds, dynamodb, cloudformation, route53, sns, sqs, and more. Use this skill
  whenever the user wants to inspect, query, troubleshoot, or manage AWS
  infrastructure, even if they don't say 'AWS' explicitly but reference cloud
  resources, ARNs, account IDs, regions, or specific AWS service names."
compatibility: "Requires aws CLI v2
  (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  with SSO authentication configured at $HOME/.aws/config. Run `aws sso login`
  to refresh expired SSO tokens before use."
metadata:
  author: Peter Benjamin
  version: 0.2.0
---

# AWS CLI Skill

Use `aws help` to explore commands and sub-commands for any service.

```sh
aws help       # all top-level commands
aws s3 help    # s3-specific commands
aws s3 ls help # s3 ls usage
```

## AWS Profiles

The AWS configuration lives in `$HOME/.aws/config`. List available profiles
with:

```sh
aws configure list-profiles
```

Profiles follow the naming convention `[profile <ACCOUNT_ID>]` or
`[profile <ACCOUNT_ALIAS>]`, so you can infer the right profile directly from an
account ID. If an error message contains an ARN, then extract the AWS Account ID
partition and pass it to `--profile` flag. If no account is specified, omit
`--profile` to use the `[default]` profile.

### SSO Token Expiry

If a command fails with `Error loading SSO Token`, the session has expired.
Refresh it:

```sh
aws sso login
```

## Output Formatting

AWS CLI defaults to JSON output. Use `--output` and `--query` (JMESPath) to
control what you see:

```sh
# Human-readable table
aws ec2 describe-instances --output table --profile <profile>

# Extract specific fields as text
aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]' \
    --output text --profile <profile>
```

## Pagination

Many commands paginate results. Use `--no-paginate` to retrieve everything in
one call (be careful on large datasets):

```sh
aws s3api list-objects-v2 --bucket <bucket> --no-paginate --profile <profile>
```

Or use `--max-items` and `--starting-token` to page manually.

## Regions

AWS defaults to the region in your profile. Override with `--region` or
`AWS_DEFAULT_REGION`:

```sh
aws ec2 describe-instances --region us-west-2 --profile <profile>
```

---

## Common Patterns

See `references/patterns.md` for CLI examples by service: EKS, EC2, S3, IAM,
KMS, Secrets Manager, Lambda, CloudWatch Logs, RDS, DynamoDB, and
CloudFormation.
