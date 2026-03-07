# Basic Example: Lambda with API Gateway

This example deploys a Python Lambda function behind an API Gateway REST API.

## Resources Created

- Lambda function with local Zip packaging
- API Gateway REST API with proxy integration
- IAM execution role with basic permissions

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
| api_url | API Gateway invoke URL |
