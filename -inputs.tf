variable "cb_accounts_map" {
  type        = map(map(object(
    {
      account_id = string
      iam_role   = string
    }
  )))
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

variable "cb_iam_role" {
  type        = string
  description = "Cross-account IAM role to assume for Terraform. This role must be created in each account that is to be affected and must be RESTRICTED ADMIN within that account to have all necessary rights. The CodeBuild service within the account which runs the pipeline and builds must be able to assume this role."
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

variable "codebuild_iam_policy" {
  type        = string
  description = "JSON string defining the initial/base codebuild IAM policy (must be passed in from caller)."
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
  description = "Prefix and key of the source artifact file. For instance, `source/master.zip`."
}

variable "cp_source_branch" {
  type        = string
  description = "Repository branch to check out. Usually `master` or `main`."
}

variable "cp_source_codestar_connection_arn" {
  type        = string
  description = "ARN of Codestar of GitHub/Bitbucket/etc connection which grants access to source repository."
  default = ""
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

variable "cp_tf_manual_approval" {
  type        = list(any)
  default     = []
  description = "List of environments for which the terraform pipeline requires manual approval prior to application stage."
}

variable "create" {
  type        = string
  default     = ""
  description = "Conditionally create resources. Affects nearly all resources."
}

variable "environment_names" {
  type        = list(string)
  default     = ["PRD"]
  description = "List of names of all the environments to create pipeline stages for."
}

#variable "s3_log_target_bucket" {
#  type        = string
#  description = "target bucket for logs"
#}

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

#Can I do a validation of Github/Bitbucket - https://www.hashicorp.com/blog/custom-variable-validation-in-terraform-0-13
variable "source_control" {
  description = "Which source control is being used?"
  type        = list(string)
  validation  = {
    condition     = contains(["GitHub","BitBucket"])
    error_message = "A valid source control provider hasn't been selected."
  }
}

#Use a reference key here from var.source_control to reference a map
variable "source_control_commit_paths" {
  description = "Source Control URL Commit Paths Map"
  type        = map(string)
  default = {
    "GitHub"    = "https://github.com/${var.cp_source_owner}/${var.cp_source_repo}/commit/#{SourceVariables.CommitId}"
    "BitBucket" = "https://bitbucket.org/${var.cp_source_owner}/${var.cp_source_repo}/commits/#{SourceVariables.CommitId}"
  }
}