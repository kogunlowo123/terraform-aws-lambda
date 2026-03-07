# Complete Example: Function URL, SnapStart, Destinations, Canary Alias

This example demonstrates the full capabilities of the Lambda module using a Java function with SnapStart, function URL, async destinations, DynamoDB Stream event source, canary alias, provisioned concurrency, and KMS encryption.

## Resources Created

- Lambda function with SnapStart enabled (Java 21)
- Function URL with CORS configuration
- Lambda alias ("live") with provisioned concurrency
- DynamoDB table with stream as event source
- SNS topics for async invocation destinations (success/failure)
- KMS key for environment variable and log encryption
- IAM execution role with DynamoDB, KMS, X-Ray, and dead letter permissions
- EventBridge trigger permission

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| None | All values are hardcoded for demonstration | - |

## Outputs

| Name | Description |
|------|-------------|
| function_name | Name of the Lambda function |
| function_arn | ARN of the Lambda function |
| function_url | Lambda function URL endpoint |
| alias_arn | ARN of the live alias |
| log_group_name | CloudWatch log group name |
