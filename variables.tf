variable "function_name" {
  description = "Unique name for the Lambda function."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,64}$", var.function_name))
    error_message = "Function name must be 1-64 characters and contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "description" {
  description = "Description of the Lambda function."
  type        = string
  default     = ""
}

variable "runtime" {
  description = "Runtime environment for the Lambda function (e.g., python3.12, nodejs20.x, java21)."
  type        = string
  default     = null

  validation {
    condition = var.runtime == null || can(regex(
      "^(python3\\.(8|9|10|11|12|13)|nodejs(16|18|20|22)\\.x|java(8|8\\.al2|11|17|21)|dotnet(6|8)|ruby3\\.(2|3|4)|go1\\.x|provided(\\.al2023|\\.al2)?)$",
      var.runtime
    ))
    error_message = "Runtime must be a valid AWS Lambda runtime identifier."
  }
}

variable "handler" {
  description = "Function entrypoint in the code (e.g., index.handler)."
  type        = string
  default     = null
}

variable "architectures" {
  description = "CPU architecture for the Lambda function (x86_64 or arm64)."
  type        = list(string)
  default     = ["arm64"]

  validation {
    condition     = length(var.architectures) == 1 && contains(["x86_64", "arm64"], var.architectures[0])
    error_message = "Architectures must contain exactly one value: either 'x86_64' or 'arm64'."
  }
}

variable "memory_size" {
  description = "Amount of memory in MB allocated to the Lambda function (128-10240)."
  type        = number
  default     = 128

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "Memory size must be between 128 MB and 10240 MB."
  }
}

variable "timeout" {
  description = "Maximum execution time in seconds for the Lambda function (1-900)."
  type        = number
  default     = 30

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds."
  }
}

variable "reserved_concurrent_executions" {
  description = "Number of concurrent executions reserved for the function (-1 for unreserved)."
  type        = number
  default     = -1

  validation {
    condition     = var.reserved_concurrent_executions >= -1
    error_message = "Reserved concurrent executions must be -1 (unreserved) or a non-negative integer."
  }
}

variable "source_path" {
  description = "Local path to the Lambda function source code directory or file."
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket containing the Lambda deployment package."
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 object key for the Lambda deployment package."
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "Version ID of the S3 object for the Lambda deployment package."
  type        = string
  default     = null
}

variable "image_uri" {
  description = "ECR image URI for container-based Lambda functions."
  type        = string
  default     = null
}

variable "package_type" {
  description = "Lambda deployment package type (Zip or Image)."
  type        = string
  default     = "Zip"

  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "Package type must be either 'Zip' or 'Image'."
  }
}

variable "layers" {
  description = "List of Lambda layer ARNs to attach to the function (max 5)."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.layers) <= 5
    error_message = "A Lambda function can have a maximum of 5 layers."
  }
}

variable "environment_variables" {
  description = "Map of environment variables to set on the Lambda function."
  type        = map(string)
  default     = {}
}

variable "enable_function_url" {
  description = "Whether to create a Lambda function URL."
  type        = bool
  default     = false
}

variable "function_url_auth_type" {
  description = "Authentication type for the function URL (NONE or AWS_IAM)."
  type        = string
  default     = "AWS_IAM"

  validation {
    condition     = contains(["NONE", "AWS_IAM"], var.function_url_auth_type)
    error_message = "Function URL auth type must be either 'NONE' or 'AWS_IAM'."
  }
}

variable "cors_config" {
  description = "CORS configuration for the Lambda function URL."
  type = object({
    allow_credentials = optional(bool, false)
    allow_headers     = optional(list(string), [])
    allow_methods     = optional(list(string), ["GET", "POST"])
    allow_origins     = optional(list(string), ["*"])
    expose_headers    = optional(list(string), [])
    max_age           = optional(number, 86400)
  })
  default = null
}

variable "enable_snapstart" {
  description = "Whether to enable SnapStart for the Lambda function (Java runtimes only)."
  type        = bool
  default     = false
}

variable "vpc_config" {
  description = "VPC configuration with subnet_ids and security_group_ids for the Lambda function."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "enable_xray_tracing" {
  description = "Whether to enable AWS X-Ray tracing for the Lambda function."
  type        = bool
  default     = true
}

variable "tracing_mode" {
  description = "X-Ray tracing mode (Active or PassThrough)."
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "Tracing mode must be either 'Active' or 'PassThrough'."
  }
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch log events."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period."
  }
}

variable "log_format" {
  description = "Log format for the Lambda function (Text or JSON)."
  type        = string
  default     = "Text"

  validation {
    condition     = contains(["Text", "JSON"], var.log_format)
    error_message = "Log format must be either 'Text' or 'JSON'."
  }
}

variable "event_source_mappings" {
  description = "List of event source mapping configurations for SQS, DynamoDB Streams, Kinesis, etc."
  type = list(object({
    event_source_arn                   = string
    batch_size                         = optional(number, 10)
    starting_position                  = optional(string, null)
    starting_position_timestamp        = optional(string, null)
    bisect_batch_on_function_error     = optional(bool, false)
    maximum_batching_window_in_seconds = optional(number, null)
    maximum_record_age_in_seconds      = optional(number, null)
    maximum_retry_attempts             = optional(number, null)
    parallelization_factor             = optional(number, null)
    enabled                            = optional(bool, true)
    function_response_types            = optional(list(string), [])
    filter_criteria = optional(list(object({
      pattern = string
    })), [])
  }))
  default = []
}

variable "on_success_arn" {
  description = "ARN of the destination resource for successful asynchronous invocations."
  type        = string
  default     = null
}

variable "on_failure_arn" {
  description = "ARN of the destination resource for failed asynchronous invocations."
  type        = string
  default     = null
}

variable "provisioned_concurrency" {
  description = "Number of provisioned concurrent executions (0 to disable)."
  type        = number
  default     = 0

  validation {
    condition     = var.provisioned_concurrency >= 0
    error_message = "Provisioned concurrency must be a non-negative integer."
  }
}

variable "alias_name" {
  description = "Name of the Lambda function alias."
  type        = string
  default     = null
}

variable "alias_description" {
  description = "Description of the Lambda function alias."
  type        = string
  default     = ""
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt environment variables and CloudWatch logs."
  type        = string
  default     = null
}

variable "dead_letter_target_arn" {
  description = "ARN of an SNS topic or SQS queue for the Lambda dead letter queue."
  type        = string
  default     = null
}

variable "allowed_triggers" {
  description = "Map of allowed triggers to create Lambda permissions."
  type = map(object({
    service    = string
    source_arn = string
    principal  = optional(string, null)
  }))
  default = {}
}

variable "tags" {
  description = "Map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
