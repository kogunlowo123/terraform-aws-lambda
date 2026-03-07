################################################################################
# Lambda Function
################################################################################

output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN to be used for invoking the Lambda function from API Gateway."
  value       = aws_lambda_function.this.invoke_arn
}

output "qualified_arn" {
  description = "Qualified ARN (ARN with version) of the Lambda function."
  value       = aws_lambda_function.this.qualified_arn
}

################################################################################
# Function URL
################################################################################

output "function_url" {
  description = "The HTTP URL endpoint for the Lambda function URL."
  value       = try(aws_lambda_function_url.this[0].function_url, null)
}

################################################################################
# Alias
################################################################################

output "alias_arn" {
  description = "ARN of the Lambda function alias."
  value       = try(aws_lambda_alias.this[0].arn, null)
}

################################################################################
# IAM Role
################################################################################

output "role_arn" {
  description = "ARN of the Lambda execution IAM role."
  value       = aws_iam_role.lambda.arn
}

output "role_name" {
  description = "Name of the Lambda execution IAM role."
  value       = aws_iam_role.lambda.name
}

################################################################################
# CloudWatch Log Group
################################################################################

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for the Lambda function."
  value       = aws_cloudwatch_log_group.lambda.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for the Lambda function."
  value       = aws_cloudwatch_log_group.lambda.name
}
