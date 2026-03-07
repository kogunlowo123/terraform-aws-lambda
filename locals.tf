locals {
  # Determine the principal for common AWS services
  service_principals = {
    apigateway  = "apigateway.amazonaws.com"
    cloudwatch  = "events.amazonaws.com"
    logs        = "logs.amazonaws.com"
    s3          = "s3.amazonaws.com"
    sns         = "sns.amazonaws.com"
    sqs         = "sqs.amazonaws.com"
    elb         = "elasticloadbalancing.amazonaws.com"
    cognito     = "cognito-idp.amazonaws.com"
    iot         = "iot.amazonaws.com"
    cloudfront  = "cloudfront.amazonaws.com"
    codecommit  = "codecommit.amazonaws.com"
    config      = "config.amazonaws.com"
    ses         = "ses.amazonaws.com"
    alexa       = "alexa-appkit.amazon.com"
    lex         = "lex.amazonaws.com"
    appsync     = "appsync.amazonaws.com"
    eventbridge = "events.amazonaws.com"
  }

  # Packaging mode detection
  use_local_file = var.source_path != null && var.package_type == "Zip"
  use_s3         = var.s3_bucket != null && var.s3_key != null
  use_image      = var.package_type == "Image" && var.image_uri != null

  # Determine filename for local packaging
  filename         = local.use_local_file ? data.archive_file.lambda[0].output_path : null
  source_code_hash = local.use_local_file ? data.archive_file.lambda[0].output_base64sha256 : null

  # CloudWatch log group name follows Lambda convention
  log_group_name = "/aws/lambda/${var.function_name}"

  # Whether VPC configuration is provided
  has_vpc_config = var.vpc_config != null

  # Whether destinations are configured
  has_destinations = var.on_success_arn != null || var.on_failure_arn != null

  # Whether an alias should be created
  create_alias = var.alias_name != null

  # Common tags applied to all resources
  common_tags = merge(
    {
      "terraform:module" = "terraform-aws-lambda"
      "ManagedBy"        = "Terraform"
    },
    var.tags,
  )
}
