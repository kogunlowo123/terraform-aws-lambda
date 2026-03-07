# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-07

### Added

- Lambda function resource with full configuration support
- Zip packaging via `archive_file` data source for local source code
- S3-based deployment package support
- Container image (ECR) deployment support
- SnapStart support for Java runtimes
- Lambda function URL with configurable CORS and authentication
- Lambda alias with version tracking for canary deployments
- Provisioned concurrency configuration on alias or version
- Event source mappings for SQS, DynamoDB Streams, and Kinesis
- Filter criteria support for event source mappings
- Async invocation destinations (on_success, on_failure)
- Lambda permissions for allowed triggers (API Gateway, EventBridge, S3, SNS, etc.)
- VPC configuration with subnet and security group attachment
- X-Ray tracing with Active/PassThrough modes
- CloudWatch log group with configurable retention and KMS encryption
- Dead letter queue configuration (SQS/SNS)
- KMS key encryption for environment variables and logs
- IAM execution role with least-privilege policies
- Conditional IAM policies for VPC, X-Ray, KMS, dead letter, and event sources
- Basic example with API Gateway integration
- Advanced example with SQS trigger, VPC, layers, and dead letter queue
- Complete example with SnapStart, function URL, destinations, and canary alias
- Comprehensive documentation with architecture diagram and cost estimation

[1.0.0]: https://github.com/kogunlowo123/terraform-aws-lambda/releases/tag/v1.0.0
