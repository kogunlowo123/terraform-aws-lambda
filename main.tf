################################################################################
# Archive (Zip Packaging)
################################################################################

data "archive_file" "lambda" {
  count = var.source_path != null && var.package_type == "Zip" ? 1 : 0

  type        = "zip"
  source_dir  = var.source_path
  output_path = "${path.module}/.build/${var.function_name}.zip"
}

################################################################################
# Lambda Execution Role
################################################################################

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.function_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count = var.vpc_config != null ? 1 : 0

  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "lambda_custom" {
  count = (
    var.dead_letter_target_arn != null ||
    var.kms_key_arn != null ||
    var.enable_xray_tracing ||
    length(var.event_source_mappings) > 0
  ) ? 1 : 0

  dynamic "statement" {
    for_each = var.dead_letter_target_arn != null ? [1] : []

    content {
      sid    = "DeadLetterQueue"
      effect = "Allow"
      actions = [
        "sqs:SendMessage",
        "sns:Publish",
      ]
      resources = [var.dead_letter_target_arn]
    }
  }

  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []

    content {
      sid    = "KMSAccess"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey",
        "kms:CreateGrant",
      ]
      resources = [var.kms_key_arn]
    }
  }

  dynamic "statement" {
    for_each = var.enable_xray_tracing ? [1] : []

    content {
      sid    = "XRayTracing"
      effect = "Allow"
      actions = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets",
        "xray:GetSamplingStatisticSummaries",
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length([
      for esm in var.event_source_mappings : esm
      if can(regex("arn:aws:sqs:", esm.event_source_arn))
    ]) > 0 ? [1] : []

    content {
      sid    = "SQSEventSource"
      effect = "Allow"
      actions = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility",
      ]
      resources = [
        for esm in var.event_source_mappings : esm.event_source_arn
        if can(regex("arn:aws:sqs:", esm.event_source_arn))
      ]
    }
  }

  dynamic "statement" {
    for_each = length([
      for esm in var.event_source_mappings : esm
      if can(regex("arn:aws:dynamodb:", esm.event_source_arn))
    ]) > 0 ? [1] : []

    content {
      sid    = "DynamoDBStreamEventSource"
      effect = "Allow"
      actions = [
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:ListStreams",
      ]
      resources = [
        for esm in var.event_source_mappings : esm.event_source_arn
        if can(regex("arn:aws:dynamodb:", esm.event_source_arn))
      ]
    }
  }

  dynamic "statement" {
    for_each = length([
      for esm in var.event_source_mappings : esm
      if can(regex("arn:aws:kinesis:", esm.event_source_arn))
    ]) > 0 ? [1] : []

    content {
      sid    = "KinesisEventSource"
      effect = "Allow"
      actions = [
        "kinesis:DescribeStream",
        "kinesis:DescribeStreamSummary",
        "kinesis:GetRecords",
        "kinesis:GetShardIterator",
        "kinesis:ListShards",
        "kinesis:ListStreams",
        "kinesis:SubscribeToShard",
      ]
      resources = [
        for esm in var.event_source_mappings : esm.event_source_arn
        if can(regex("arn:aws:kinesis:", esm.event_source_arn))
      ]
    }
  }
}

resource "aws_iam_role_policy" "lambda_custom" {
  count = length(data.aws_iam_policy_document.lambda_custom) > 0 ? 1 : 0

  name   = "${var.function_name}-custom-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_custom[0].json
}

################################################################################
# Lambda Function
################################################################################

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = aws_iam_role.lambda.arn

  filename         = var.source_path != null && var.package_type == "Zip" ? data.archive_file.lambda[0].output_path : null
  source_code_hash = var.source_path != null && var.package_type == "Zip" ? data.archive_file.lambda[0].output_base64sha256 : null

  s3_bucket         = var.s3_bucket != null && var.s3_key != null ? var.s3_bucket : null
  s3_key            = var.s3_bucket != null && var.s3_key != null ? var.s3_key : null
  s3_object_version = var.s3_bucket != null && var.s3_key != null ? var.s3_object_version : null

  package_type = var.package_type
  image_uri    = var.package_type == "Image" && var.image_uri != null ? var.image_uri : null

  runtime       = var.package_type == "Zip" ? var.runtime : null
  handler       = var.package_type == "Zip" ? var.handler : null
  architectures = var.architectures
  layers        = var.package_type == "Zip" ? var.layers : null

  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []

    content {
      variables = var.environment_variables
    }
  }

  dynamic "snap_start" {
    for_each = var.enable_snapstart ? [1] : []

    content {
      apply_on = "PublishedVersions"
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []

    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  dynamic "tracing_config" {
    for_each = var.enable_xray_tracing ? [1] : []

    content {
      mode = var.tracing_mode
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != null ? [1] : []

    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  kms_key_arn = var.kms_key_arn

  logging_config {
    log_format = var.log_format
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  publish = var.alias_name != null || var.provisioned_concurrency > 0

  tags = var.tags

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
  qualifier          = var.alias_name != null ? aws_lambda_alias.this[0].name : null
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
  count = var.alias_name != null ? 1 : 0

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
  qualifier                      = var.alias_name != null ? aws_lambda_alias.this[0].name : aws_lambda_function.this.version
  provisioned_concurrent_executions = var.provisioned_concurrency
}

################################################################################
# Event Source Mappings
################################################################################

resource "aws_lambda_event_source_mapping" "this" {
  count = length(var.event_source_mappings)

  function_name    = var.alias_name != null ? aws_lambda_alias.this[0].arn : aws_lambda_function.this.arn
  event_source_arn = var.event_source_mappings[count.index].event_source_arn
  batch_size       = var.event_source_mappings[count.index].batch_size
  enabled          = var.event_source_mappings[count.index].enabled

  starting_position           = var.event_source_mappings[count.index].starting_position
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
  count = var.on_success_arn != null || var.on_failure_arn != null ? 1 : 0

  function_name = aws_lambda_function.this.function_name
  qualifier     = var.alias_name != null ? aws_lambda_alias.this[0].name : null

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
  qualifier     = var.alias_name != null ? aws_lambda_alias.this[0].name : null
  principal     = coalesce(each.value.principal, "${each.value.service}.amazonaws.com")
  source_arn    = each.value.source_arn
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}
