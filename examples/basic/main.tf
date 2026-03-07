################################################################################
# Basic Example: Lambda with API Gateway Trigger
################################################################################

provider "aws" {
  region = "us-east-1"
}

module "lambda" {
  source = "../../"

  function_name = "basic-api-handler"
  description   = "Basic Lambda function with API Gateway trigger"
  runtime       = "python3.12"
  handler       = "handler.handler"
  architectures = ["arm64"]

  source_path = "${path.module}/src"

  memory_size = 256
  timeout     = 30

  environment_variables = {
    ENVIRONMENT = "production"
    LOG_LEVEL   = "INFO"
  }

  allowed_triggers = {
    api_gateway = {
      service    = "apigateway"
      source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
    }
  }

  tags = {
    Environment = "production"
    Project     = "basic-example"
  }
}

################################################################################
# API Gateway
################################################################################

resource "aws_api_gateway_rest_api" "this" {
  name        = "basic-lambda-api"
  description = "API Gateway for basic Lambda example"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  depends_on = [aws_api_gateway_integration.proxy]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = "v1"
}

################################################################################
# Outputs
################################################################################

output "function_name" {
  value = module.lambda.function_name
}

output "api_url" {
  value = aws_api_gateway_stage.this.invoke_url
}
