# Advanced Example: Lambda with SQS, VPC, and Layers

This example deploys a Lambda function within a VPC, triggered by an SQS queue, with a shared dependencies layer and dead letter queue.

## Resources Created

- Lambda function with VPC configuration
- SQS source queue with event source mapping and filter criteria
- SQS dead letter queue
- Lambda layer for shared dependencies
- Security group for Lambda VPC access
- IAM execution role with VPC, SQS, and X-Ray permissions

## Usage

```bash
# Create a dummy layer zip first
mkdir -p layers && cd layers
mkdir -p python && zip -r dependencies.zip python/
cd ..

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
| sqs_queue_url | URL of the source SQS queue |
