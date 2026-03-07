################################################################################
# Advanced Example: Lambda with SQS Trigger, VPC, and Layers
################################################################################

provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "lambda" {
  name_prefix = "lambda-advanced-"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lambda-advanced-sg"
  }
}

################################################################################
# SQS Queue
################################################################################

resource "aws_sqs_queue" "source" {
  name                       = "lambda-event-source"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400

  tags = {
    Environment = "staging"
  }
}

resource "aws_sqs_queue" "dlq" {
  name                      = "lambda-dlq"
  message_retention_seconds = 1209600

  tags = {
    Environment = "staging"
  }
}

################################################################################
# Lambda Layer (example with AWS SDK extras)
################################################################################

resource "aws_lambda_layer_version" "dependencies" {
  filename            = "${path.module}/layers/dependencies.zip"
  layer_name          = "python-dependencies"
  compatible_runtimes = ["python3.12"]
  description         = "Shared Python dependencies layer"
}

################################################################################
# Lambda Function
################################################################################

module "lambda" {
  source = "../../"

  function_name = "advanced-sqs-processor"
  description   = "Advanced Lambda processing SQS messages within a VPC"
  runtime       = "python3.12"
  handler       = "handler.handler"
  architectures = ["arm64"]

  source_path = "${path.module}/src"

  memory_size = 512
  timeout     = 60

  layers = [aws_lambda_layer_version.dependencies.arn]

  environment_variables = {
    ENVIRONMENT    = "staging"
    LOG_LEVEL      = "DEBUG"
    SQS_QUEUE_URL  = aws_sqs_queue.source.url
  }

  vpc_config = {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  dead_letter_target_arn = aws_sqs_queue.dlq.arn

  event_source_mappings = [
    {
      event_source_arn                   = aws_sqs_queue.source.arn
      batch_size                         = 5
      maximum_batching_window_in_seconds = 30
      function_response_types            = ["ReportBatchItemFailures"]
      filter_criteria = [
        {
          pattern = jsonencode({
            body = {
              type = ["order", "payment"]
            }
          })
        }
      ]
    }
  ]

  enable_xray_tracing = true
  tracing_mode        = "Active"
  log_retention_days  = 14
  log_format          = "JSON"

  tags = {
    Environment = "staging"
    Project     = "advanced-example"
  }
}

################################################################################
# Outputs
################################################################################

output "function_name" {
  value = module.lambda.function_name
}

output "function_arn" {
  value = module.lambda.function_arn
}

output "sqs_queue_url" {
  value = aws_sqs_queue.source.url
}
