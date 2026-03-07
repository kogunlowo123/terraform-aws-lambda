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
  name = "${var.function_name}-execution-role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.common_tags
}

################################################################################
# AWS Managed Policy: Basic Execution (CloudWatch Logs)
################################################################################

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

################################################################################
# AWS Managed Policy: VPC Access (Conditional)
################################################################################

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count = local.has_vpc_config ? 1 : 0

  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

################################################################################
# Custom Policy: Dead Letter Queue, KMS, X-Ray, Event Sources
################################################################################

data "aws_iam_policy_document" "lambda_custom" {
  count = (
    var.dead_letter_target_arn != null ||
    var.kms_key_arn != null ||
    var.enable_xray_tracing ||
    length(var.event_source_mappings) > 0
  ) ? 1 : 0

  # Dead letter queue permissions
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

  # KMS permissions for encrypting/decrypting environment variables
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

  # X-Ray tracing permissions
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

  # Event source mapping permissions (SQS)
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

  # Event source mapping permissions (DynamoDB Streams)
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

  # Event source mapping permissions (Kinesis)
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
