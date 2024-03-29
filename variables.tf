variable "cb_accounts_map" {
  type = map(object(
    {
      account_id      = string
      iam_role        = string
      manual_approval = bool
      order           = number
    }
  ))
  description = "Map of environments, IAM assumption roles, AWS accounts to create pipeline stages for.cb_accounts_map = {dev = {account_id = 123456789012; iam_role = \"stringrolename\"}}"
}
variable "cb_apply_timeout" {
  type        = number
  default     = 60
  description = "Maximum time in minutes to wait while applying terraform before killing the build."
}

variable "cb_env_compute_type" {
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
  description = "Size of instance to run Codebuild within. Valid Values are BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE, BUILD_GENERAL1_2XLARGE."
}

variable "cb_env_image" {
  type        = string
  default     = "aws/codebuild/standard:5.0"
  description = "Identifies the Docker image to use for this build project. Available images documented in [the official AWS Codebuild documentation](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html)."
}

variable "cb_env_image_pull_credentials_type" {
  type        = string
  default     = "CODEBUILD"
  description = "The type of credentials AWS CodeBuild uses to pull images in your build. There are two valid values described in [the ProjectEnvironment documentation](https://docs.aws.amazon.com/codebuild/latest/APIReference/API_ProjectEnvironment.html)."
}

variable "cb_env_name" {
  type        = string
  description = "Should be referenced from env_name of calling terraform module."
}

variable "cb_env_type" {
  type        = string
  default     = "LINUX_CONTAINER"
  description = "Codebuild Environment to use for stages in the pipeline. Valid Values are documented at [the ProjectEnvironment documentation](https://docs.aws.amazon.com/codebuild/latest/APIReference/API_ProjectEnvironment.html)."
}

variable "cb_plan_timeout" {
  type        = number
  default     = 15
  description = "Maximum time in minutes to wait while generating terraform plan before killing the build."
}

variable "cb_tf_version" {
  type        = string
  description = "Version of terraform to download and install. Must match version scheme used for URL creation on terraform site."
}

variable "cb_gh_app_id" {
  type        = string
  description = "ID of the GitHub App."
  default     = ""
}

variable "cb_gh_app_installation_id" {
  type        = string
  description = "Installation ID of the GitHub App."
  default     = ""
}

variable "cb_gh_private_key_arn" {
  type        = string
  description = "Secret's ARN containing the binary of the private key for the GitHub App."
  default     = ""
}

variable "codebuild_iam_policy" {
  type        = string
  description = "JSON string defining the initial/base codebuild IAM policy (must be passed in from caller)."
}

variable "cp_resource_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket where the source artifacts exist."
}

variable "cp_resource_bucket_name" {
  type        = string
  description = "Name of the S3 bucket where the source artifacts exist."
}

variable "cp_resource_bucket_key_name" {
  type        = string
  description = "Prefix and key of the source artifact file. For instance, `source/master.zip`."
}

variable "cp_resource_bucket_kms_key_arn" {
  description = "ARN of customer-manged KMS key used to encrypt objects in the source/resource bucket. Optional."
  type        = string
  default     = ""
}

variable "cp_source_branch" {
  type        = string
  description = "Repository branch to check out. Usually `master` or `main`."
}

variable "cp_source_codestar_connection_arn" {
  type        = string
  description = "ARN of Codestar of GitHub/Bitbucket/etc connection which grants access to source repository."
  default     = ""
}

variable "cp_source_owner" {
  type        = string
  description = "GitHub/Bitbucket organization username."
}

variable "cp_source_poll_for_changes" {
  type        = bool
  default     = false
  description = "Cause codepipeline to poll regularly for source code changes instead of waiting for CloudWatch Events. This is not required with a Codestar connection and should be avoided unless Codestar and webhooks are unavailable."
}

variable "cp_source_repo" {
  type        = string
  description = "Name of repository to clone."
}

variable "create" {
  type        = bool
  default     = true
  description = "Conditionally create resources. Affects nearly all resources."
}

variable "input_tags" {
  description = "Map of tags to apply to all taggable resources."
  type        = map(string)
  default = {
    Provisioner = "Terraform"
  }
}

variable "name" {
  type        = string
  default     = "codepipline-module"
  description = "Name to prepend to all resource names within module."
}

variable "init_tfvars" {
  description = "The path for the TFVars Init folder, this is the full relative path. I.E ./init-tfvars"
  type        = string
  default     = "./init-tfvars"
}

variable "apply_tfvars" {
  description = "The path for the TFVars Apply folder, this is the full relative path"
  type        = string
  default     = "./apply-tfvars"
}

# https://www.hashicorp.com/blog/custom-variable-validation-in-terraform-0-13
# https://medium.com/codex/terraform-variable-validation-b9b3e7eddd79
variable "source_control" {
  description = "Which source control is being used?"
  type        = string
  validation {
    condition     = contains(["GitHub", "BitBucket"], var.source_control)
    error_message = "A valid source control provider hasn't been selected."
  }
}

# Uses a reference key here from var.source_control to reference a map
variable "source_control_commit_paths" {
  description = "Source Control URL Commit Paths Map"
  type        = map(map(string))
  default = {
    GitHub = {
      path1 = "https://github.com"
      path2 = "commit"
    }
    BitBucket = {
      path1 = "https://bitbucket.org"
      path2 = "commits"
    }
  }
}

variable "slack_notification_for_approval" {
  type        = bool
  default     = false
  description = "When true - AWS chatbot service is created along with a lambda function to approve codepipeline manual approval stage"
}

variable "slack_workspace_id" {
  description = "The workspace ID for slack account to be used for notifications"
  type        = string
  default     = "T01T01ABC"
}

variable "slack_channel_id" {
  description = "The chanel ID for slack workspace where notifications are sent"
  type        = string
  default     = "F123CCAB1A"
}
