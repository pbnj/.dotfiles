# AWS CLI Patterns by Service

## EKS

```sh
# List clusters
aws eks list-clusters --profile <profile>

# Describe a cluster
aws eks describe-cluster --name <cluster-name> --profile <profile>

# List node groups
aws eks list-nodegroups --cluster-name <cluster-name> --profile <profile>
```

## EC2

```sh
# Describe instances (filter by tag)
aws ec2 describe-instances \
    --filters "Name=tag:Env,Values=prod" \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Tags]' \
    --profile <profile>

# Describe security groups
aws ec2 describe-security-groups --group-ids sg-XXXXXXXX --profile <profile>

# Describe VPCs
aws ec2 describe-vpcs --profile <profile>
```

## S3

```sh
# List buckets
aws s3 ls --profile <profile>

# Get bucket policy
aws s3api get-bucket-policy --bucket <bucket-name> --profile <profile>

# Get bucket ACL
aws s3api get-bucket-acl --bucket <bucket-name> --profile <profile>

# List objects (summary)
aws s3 ls s3://<bucket-name>/ --recursive --human-readable --summarize --profile <profile>
```

## IAM

```sh
# Get role details
aws iam get-role --role-name <role-name> --profile <profile>

# List attached role policies
aws iam list-attached-role-policies --role-name <role-name> --profile <profile>

# Get policy document (fetches current version automatically)
aws iam get-policy-version \
    --policy-arn <policy-arn> \
    --version-id $(aws iam get-policy --policy-arn <policy-arn> \
        --query 'Policy.DefaultVersionId' --output text --profile <profile>) \
    --profile <profile>

# List users
aws iam list-users --profile <profile>
```

## KMS / Secrets Manager

```sh
# List KMS keys
aws kms list-keys --profile <profile>

# Describe a KMS key
aws kms describe-key --key-id <key-id> --profile <profile>

# List secrets
aws secretsmanager list-secrets --profile <profile>

# Get secret metadata (not value) — use describe-secret; avoid get-secret-value unless asked
aws secretsmanager describe-secret --secret-id <secret-name> --profile <profile>
```

## Lambda

```sh
# List functions
aws lambda list-functions --profile <profile>

# Get function configuration
aws lambda get-function-configuration --function-name <name> --profile <profile>

# View recent invocation errors (last 1 hour)
aws logs filter-log-events \
    --log-group-name /aws/lambda/<function-name> \
    --start-time $(date -d '1 hour ago' +%s000 2>/dev/null || date -v-1H +%s000) \
    --filter-pattern "ERROR" \
    --profile <profile>
```

## CloudWatch Logs

```sh
# List log groups
aws logs describe-log-groups --profile <profile>

# List log streams for a group
aws logs describe-log-streams \
    --log-group-name <group-name> \
    --order-by LastEventTime --descending \
    --profile <profile>

# Tail recent log events
aws logs get-log-events \
    --log-group-name <group-name> \
    --log-stream-name <stream-name> \
    --limit 50 \
    --profile <profile>
```

## RDS

```sh
# List DB instances
aws rds describe-db-instances --profile <profile>

# Describe a specific instance
aws rds describe-db-instances --db-instance-identifier <id> --profile <profile>
```

## DynamoDB

```sh
# List tables
aws dynamodb list-tables --profile <profile>

# Describe a table
aws dynamodb describe-table --table-name <table-name> --profile <profile>
```

## CloudFormation

```sh
# List stacks
aws cloudformation list-stacks --profile <profile>

# Describe a stack
aws cloudformation describe-stacks --stack-name <stack-name> --profile <profile>

# List stack resources
aws cloudformation list-stack-resources --stack-name <stack-name> --profile <profile>
```
