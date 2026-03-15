terraform {
  required_version = ">= 1.7.0"
}

module "test" {
  source = "../"

  function_name = "test-lambda-function"
  description   = "Test Lambda function for module validation"
  runtime       = "python3.12"
  handler       = "index.handler"
  source_path   = "${path.module}/fixtures/lambda"
  memory_size   = 128
  timeout       = 30
  architectures = ["arm64"]

  environment_variables = {
    ENVIRONMENT = "test"
  }

  tags = {
    Environment = "test"
    Module      = "terraform-aws-lambda"
  }
}
