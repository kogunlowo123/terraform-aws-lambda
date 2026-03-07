################################################################################
# Complete Example: Function URL, SnapStart, Destinations, Canary Alias
################################################################################

provider "aws" {
  region = "us-east-1"
}

################################################################################
# KMS Key for Encryption
################################################################################

resource "aws_kms_key" "lambda" {
  description             = "KMS key for Lambda environment variables and logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Environment = "production"
  }
}

resource "aws_kms_alias" "lambda" {
  name          = "alias/lambda-complete-example"
  target_key_id = aws_kms_key.lambda.key_id
}

################################################################################
# SNS Topics for Destinations
################################################################################

resource "aws_sns_topic" "on_success" {
  name = "lambda-on-success"
}

resource "aws_sns_topic" "on_failure" {
  name = "lambda-on-failure"
}

################################################################################
# DynamoDB Table with Stream
################################################################################

resource "aws_dynamodb_table" "events" {
  name             = "lambda-events"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "id"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Environment = "production"
  }
}

################################################################################
# Lambda Function (Java with SnapStart)
################################################################################

module "lambda_snapstart" {
  source = "../../"

  function_name = "complete-java-handler"
  description   = "Complete Lambda with SnapStart, function URL, destinations, and canary alias"
  runtime       = "java21"
  handler       = "com.example.Handler::handleRequest"
  architectures = ["arm64"]

  s3_bucket = "my-deployment-bucket"
  s3_key    = "lambda/complete-handler-1.0.0.jar"

  memory_size                    = 1024
  timeout                        = 60
  reserved_concurrent_executions = 100

  enable_snapstart = true

  environment_variables = {
    ENVIRONMENT   = "production"
    TABLE_NAME    = aws_dynamodb_table.events.name
    SUCCESS_TOPIC = aws_sns_topic.on_success.arn
  }

  # Function URL with CORS
  enable_function_url    = true
  function_url_auth_type = "NONE"
  cors_config = {
    allow_credentials = true
    allow_headers     = ["Content-Type", "Authorization", "X-Request-Id"]
    allow_methods     = ["GET", "POST", "PUT", "DELETE"]
    allow_origins     = ["https://example.com", "https://app.example.com"]
    expose_headers    = ["X-Request-Id"]
    max_age           = 3600
  }

  # Alias with canary support
  alias_name        = "live"
  alias_description = "Production alias for canary deployments"

  # Provisioned concurrency on the alias
  provisioned_concurrency = 5

  # Async invocation destinations
  on_success_arn = aws_sns_topic.on_success.arn
  on_failure_arn = aws_sns_topic.on_failure.arn

  # DynamoDB Stream event source
  event_source_mappings = [
    {
      event_source_arn               = aws_dynamodb_table.events.stream_arn
      starting_position              = "LATEST"
      batch_size                     = 100
      bisect_batch_on_function_error = true
      maximum_retry_attempts         = 3
      maximum_record_age_in_seconds  = 3600
      parallelization_factor         = 5
      filter_criteria = [
        {
          pattern = jsonencode({
            eventName = ["INSERT", "MODIFY"]
          })
        }
      ]
    }
  ]

  # Security
  kms_key_arn           = aws_kms_key.lambda.arn
  dead_letter_target_arn = aws_sns_topic.on_failure.arn

  # Observability
  enable_xray_tracing = true
  tracing_mode        = "Active"
  log_retention_days  = 90
  log_format          = "JSON"

  # Allowed triggers
  allowed_triggers = {
    eventbridge = {
      service    = "eventbridge"
      source_arn = "arn:aws:events:us-east-1:123456789012:rule/my-scheduled-rule"
    }
  }

  tags = {
    Environment = "production"
    Project     = "complete-example"
    CostCenter  = "engineering"
  }
}

################################################################################
# Outputs
################################################################################

output "function_name" {
  value = module.lambda_snapstart.function_name
}

output "function_arn" {
  value = module.lambda_snapstart.function_arn
}

output "function_url" {
  value = module.lambda_snapstart.function_url
}

output "alias_arn" {
  value = module.lambda_snapstart.alias_arn
}

output "log_group_name" {
  value = module.lambda_snapstart.log_group_name
}
