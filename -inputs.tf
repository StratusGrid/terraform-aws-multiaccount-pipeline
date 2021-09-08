variable "cb_accounts_map" {
  type        = map(map(string))
  description = "Map of environments and AWS accounts."
}
variable "cb_apply_timeout" {
  type        = number
  default     = 60
  description = "Maximum time in minutes to wait while applying terraform before killing the build"
}

variable "cb_env_compute_type" {
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
  description = "Valid Values are BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE, BUILD_GENERAL1_2XLARGE"
}

variable "cb_env_image" {
  type        = string
  default     = "aws/codebuild/standard:2.0"
  description = "The image tag or image digest that identifies the Docker image to use for this build project."
}

#https://docs.aws.amazon.com/codebuild/latest/APIReference/API_ProjectEnvironment.html
variable "cb_env_image_pull_credentials_type" {
  type        = string
  default     = "CODEBUILD"
  description = "The type of credentials AWS CodeBuild uses to pull images in your build. There are two valid values"
}

variable "cb_env_name" {
  type        = string
  description = "should pull from env_name of calling terraform."
}


variable "cb_env_type" {
  type        = string
  default     = "LINUX_CONTAINER"
  description = "Codebuild Environment to use for stages in the pipeline. Valid Values are WINDOWS_CONTAINER, LINUX_CONTAINER, LINUX_GPU_CONTAINER, ARM_CONTAINER"
}

variable "cb_iam_role" {
  type        = string
  description = "IAM role to assume for Terraform. Must be ADMIN."
}

variable "cb_plan_timeout" {
  type        = number
  default     = 15
  description = "Maximum time in minutes to wait while generating terraform plan before killing the build"
}

variable "cb_tf_version" {
  type        = string
  description = "Version of terraform to download and install. Must match version scheme used for URL creation on terraform site."
}

variable "codebuild_iam_policy" {
  type        = string
  description = "JSON string defining codebuild IAM policy (must be passed in from caller)."
}

variable "cp_resource_bucket_arn" {
  type = string
  description = "ARN of the S3 bucket where the source artifacts exist."
}

variable "cp_resource_bucket_name" {
  type = string
  description = "Name of the S3 bucket where the source artifacts exist."
}

variable "cp_resource_bucket_key_name" {
  type = string
  description = "Name of the source artifact file."
}

variable "cp_source_branch" {
  type        = string
  description = "repository branch. for our purposes, this is often the same as the name of the environment (dev/qa/prd)."
}

variable "cp_source_codestar_connection_arn" {
  type        = string
  description = "Codestar GitHub connection arn which grants access to source repository."
  default = ""
}

variable "cp_source_owner" {
  type        = string
  description = "GitHub user account name"
}

variable "cp_source_poll_for_changes" {
  type        = bool
  description = "true/false should codepipeline poll for source code changes."
}

variable "cp_source_repo" {
  type        = string
  description = "name of repository to clone"
}

variable "cp_tf_manual_approval" {
  type        = list(any)
  default     = []
  description = "determines if terraform pipeline requires manual approval for application."
}

variable "create" {
  type        = string
  default     = ""
  description = "conditionally create resources"
}

variable "environment_names" {
  type        = list(string)
  default     = ["PRD"]
  description = "names of all the environments to create"
}

#variable "s3_log_target_bucket" {
#  type        = string
#  description = "target bucket for logs"
#}

variable "input_tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default = {
    Provisioner = "Terraform"
  }
}

variable "name" {
  type        = string
  default     = "codepipline-module"
  description = "name to prepend to all resource names within module"
}

