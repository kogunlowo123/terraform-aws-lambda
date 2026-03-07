################################################################################
# Archive (Zip Packaging)
################################################################################

data "archive_file" "lambda" {
  count = local.use_local_file ? 1 : 0

  type        = "zip"
  source_dir  = var.source_path
  output_path = "${path.module}/.build/${var.function_name}.zip"
}

################################################################################
# Lambda Function
################################################################################

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = aws_iam_role.lambda.arn

  # Zip packaging (local file)
  filename         = local.filename
  source_code_hash = local.source_code_hash

  # Zip packaging (S3)
  s3_bucket         = local.use_s3 ? var.s3_bucket : null
  s3_key            = local.use_s3 ? var.s3_key : null
  s3_object_version = local.use_s3 ? var.s3_object_version : null

  # Container packaging
  package_type = var.package_type
  image_uri    = local.use_image ? var.image_uri : null

  # Runtime configuration (Zip only)
  runtime       = var.package_type == "Zip" ? var.runtime : null
  handler       = var.package_type == "Zip" ? var.handler : null
  architectures = var.architectures
  layers        = var.package_type == "Zip" ? var.layers : null

  # Execution limits
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # Environment variables
  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []

    content {
      variables = var.environment_variables
    }
  }

  # SnapStart (Java runtimes only)
  dynamic "snap_start" {
    for_each = var.enable_snapstart ? [1] : []

    content {
      apply_on = "PublishedVersions"
    }
  }

  # VPC configuration
  dynamic "vpc_config" {
    for_each = local.has_vpc_config ? [var.vpc_config] : []

    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  # X-Ray tracing
  dynamic "tracing_config" {
    for_each = var.enable_xray_tracing ? [1] : []

    content {
      mode = var.tracing_mode
    }
  }

  # Dead letter queue
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != null ? [1] : []

    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  # KMS encryption for environment variables
  kms_key_arn = var.kms_key_arn

  # Logging configuration
  logging_config {
    log_format = var.log_format
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  # Publish a version when alias or provisioned concurrency is configured
  publish = local.create_alias || var.provisioned_concurrency > 0

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_cloudwatch_log_group.lambda,
  ]
}

################################################################################
# Function URL
################################################################################

resource "aws_lambda_function_url" "this" {
  count = var.enable_function_url ? 1 : 0

  function_name      = aws_lambda_function.this.function_name
  qualifier          = local.create_alias ? aws_lambda_alias.this[0].name : null
  authorization_type = var.function_url_auth_type

  dynamic "cors" {
    for_each = var.cors_config != null ? [var.cors_config] : []

    content {
      allow_credentials = cors.value.allow_credentials
      allow_headers     = cors.value.allow_headers
      allow_methods     = cors.value.allow_methods
      allow_origins     = cors.value.allow_origins
      expose_headers    = cors.value.expose_headers
      max_age           = cors.value.max_age
    }
  }
}

################################################################################
# Alias
################################################################################

resource "aws_lambda_alias" "this" {
  count = local.create_alias ? 1 : 0

  name             = var.alias_name
  description      = var.alias_description
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version
}

################################################################################
# Provisioned Concurrency
################################################################################

resource "aws_lambda_provisioned_concurrency_config" "this" {
  count = var.provisioned_concurrency > 0 ? 1 : 0

  function_name                  = aws_lambda_function.this.function_name
  qualifier                      = local.create_alias ? aws_lambda_alias.this[0].name : aws_lambda_function.this.version
  provisioned_concurrent_executions = var.provisioned_concurrency
}

################################################################################
# Event Source Mappings
################################################################################

resource "aws_lambda_event_source_mapping" "this" {
  count = length(var.event_source_mappings)

  function_name    = local.create_alias ? aws_lambda_alias.this[0].arn : aws_lambda_function.this.arn
  event_source_arn = var.event_source_mappings[count.index].event_source_arn
  batch_size       = var.event_source_mappings[count.index].batch_size
  enabled          = var.event_source_mappings[count.index].enabled

  starting_position          = var.event_source_mappings[count.index].starting_position
  starting_position_timestamp = var.event_source_mappings[count.index].starting_position_timestamp

  bisect_batch_on_function_error     = var.event_source_mappings[count.index].bisect_batch_on_function_error
  maximum_batching_window_in_seconds = var.event_source_mappings[count.index].maximum_batching_window_in_seconds
  maximum_record_age_in_seconds      = var.event_source_mappings[count.index].maximum_record_age_in_seconds
  maximum_retry_attempts             = var.event_source_mappings[count.index].maximum_retry_attempts
  parallelization_factor             = var.event_source_mappings[count.index].parallelization_factor

  function_response_types = var.event_source_mappings[count.index].function_response_types

  dynamic "filter_criteria" {
    for_each = length(var.event_source_mappings[count.index].filter_criteria) > 0 ? [1] : []

    content {
      dynamic "filter" {
        for_each = var.event_source_mappings[count.index].filter_criteria

        content {
          pattern = filter.value.pattern
        }
      }
    }
  }
}

################################################################################
# Async Invocation Destinations
################################################################################

resource "aws_lambda_function_event_invoke_config" "this" {
  count = local.has_destinations ? 1 : 0

  function_name = aws_lambda_function.this.function_name
  qualifier     = local.create_alias ? aws_lambda_alias.this[0].name : null

  destination_config {
    dynamic "on_success" {
      for_each = var.on_success_arn != null ? [1] : []

      content {
        destination = var.on_success_arn
      }
    }

    dynamic "on_failure" {
      for_each = var.on_failure_arn != null ? [1] : []

      content {
        destination = var.on_failure_arn
      }
    }
  }
}

################################################################################
# Lambda Permissions (Allowed Triggers)
################################################################################

resource "aws_lambda_permission" "this" {
  for_each = var.allowed_triggers

  statement_id  = "AllowInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  qualifier     = local.create_alias ? aws_lambda_alias.this[0].name : null
  principal     = coalesce(each.value.principal, lookup(local.service_principals, each.value.service, "${each.value.service}.amazonaws.com"))
  source_arn    = each.value.source_arn
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "lambda" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.common_tags
}
