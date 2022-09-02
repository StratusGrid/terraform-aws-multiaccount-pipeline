<!-- BEGIN_TF_DOCS -->
# Terraform Multiaccount Pipeline

[StratusGrid/terraform-aws-multiaccount-pipeline](https://github.com/StratusGrid/terraform-aws-multiaccount-pipeline)

## Terraform module to create a CICD pipeline for Terraform which can execute from a Production or CICD account across multiple sub-accounts which each contain a specific environment.

---

## Cross-Account Role Assumption

In order for the CodePipeline's CodeBuild stages to properly function in each account/environment, an IAM role must be created in each account which the CodeBuilds can assume.  Thus, you should create an IAM role in each account with the same name and [restricted ADMIN rights](https://github.com/StratusGrid/terraform-aws-iam-group-restricted-admin), establish trust relationships to allow the CICD account to assume that role, and then provide the CodeBuild execution roles with STS Assume role rights for that role. This role's name is defined in the cb_accounts_map map parameter. The listed role works assuming you remove the sts:AssumeRole deny.

An example policy to this is located [here](IAM-POLICY.md).

## Slack and AWS ChatBot Integration

This module comes with a native AWS Chatbot integration hook, to enable this follow the below steps,
1. Simply set `slack_notification_for_approval` to true and fill out your Workspace ID and Channel ID.
2. Install the [AWS Chatbot](https://stratusgrid.slack.com/apps/A6L22LZNH-aws-chatbot) app into the Slack Workspace and the channel if it's a private channel.
3. Navigate to the AWS Chatbot Service in the AWS Console and authorize the Slack Workspace.
4. It may fail to deploy the first time due to an underlying AWS config replication, if it does wait up to 15 minutes as the error message states.

---

## Example with Git Source

```hcl
module "terraform_pipeline" {
  source  = "StratusGrid/multiaccount-pipeline/aws"
  version = "~> 3.0.0"

  create                             = true
  name                               = "${var.name_prefix}-utils"
  codebuild_iam_policy               = local.terraform_pipeline_codebuild_policy
  cb_env_compute_type                = "BUILD_GENERAL1_SMALL"
  cb_env_image                       = "aws/codebuild/standard:5.0"
  cb_env_type                        = "LINUX_CONTAINER"
  cb_tf_version                      = var.terraform_version
  cb_env_name                        = var.env_name
  cp_source_owner                    = "myorg" # (GitHub/BitBucket Org) - (Organization Name/Project Name)
  cp_source_repo                     = "myrepo" # Repository Name
  cp_source_branch                   = "main" #Branch
  cb_env_image_pull_credentials_type = "CODEBUILD"
  cp_source_codestar_connection_arn  = aws_codestarconnections_connection.codestar_connection_name.arn
  source_control                     = "GitHub" #GitHub or BitBucket

  # This is used to authenticate against GitHub using a GitHub App. Git will be configured with a temporal token from the GitHub App.
  # https://docs.github.com/en/developers/apps/building-github-apps/authenticating-with-github-apps
  cb_gh_app_id                       = var.cb_gh_app_id
  cb_gh_app_installation_id          = var.cb_gh_app_installation_id
  cb_gh_private_key_arn              = aws_secretsmanager_secret.github_app.id
  
  # This is part of an or statement, this section is meant for if your artifacts are local and not in GIT. Use whitespace to emulate nulls, they must still be defined.
  cp_resource_bucket_arn             = ""
  cp_resource_bucket_name            = ""
  cp_resource_bucket_key_name        = ""
  cp_source_poll_for_changes         = true

  # This is used to enable slack notifications for codebuild statuses as well as codepipeline manual approval via AWS chatbot service 
  slack_notification_for_approval    = true
  slack_workspace_id                 = ""
  slack_channel_id                   = ""
  
  # Each environment but be in the order, we prefix this list since the map will sort alphabetically and we can not change that.
  # We make an assumption that the environment name matches the environment name in the TF init and apply directories.
  cb_accounts_map = {
    "dev" = {
      account_id = "0012345678901"
      iam_role   = "iam-cicd"
      manual_approval = false
      order = 1
    }
    "stg" = {
      account_id = "123456789012"
      iam_role   = "iam-cicd"
      manual_approval = true
      order = 2
    }
    "prd" = {
      account_id = "234567890123"
      iam_role   = "iam-cicd"
      manual_approval = true
      order = 3
    }
  }
}

locals {
  terraform_pipeline_codebuild_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${var.backend_name}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::${var.backend_name}/${var.name_prefix}-infra-utils-${var.env_name}.tfstate"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/${var.backend_name}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "${var.tf_kms_key_id}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "${module.terraform_pipeline.codepipeline_resources_bucket_arn}",
        "${module.terraform_pipeline.codepipeline_resources_bucket_arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Describe*",
        "kms:Get*",
        "kms:List*",
        "iam:*",
        "codepipeline:*",
        "codebuild:*",
        "codedeploy:*",
        "s3:CreateBucket",
        "s3:List*",
        "s3:Get*",
        "sts:AssumeRole"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:Describe*",
        "secretsmanager:Get*",
        "secretsmanager:List*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
POLICY
}
```

---

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.12 |

## Resources

| Name | Type |
|------|------|
| [aws_codebuild_project.terraform_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) | resource |
| [aws_codebuild_project.terraform_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) | resource |
| [aws_codepipeline.codepipeline_terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline) | resource |
| [aws_codestarnotifications_notification_rule.apply_stats](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codestarnotifications_notification_rule) | resource |
| [aws_codestarnotifications_notification_rule.approval_needed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codestarnotifications_notification_rule) | resource |
| [aws_codestarnotifications_notification_rule.plan_stats](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codestarnotifications_notification_rule) | resource |
| [aws_iam_policy.chatbot_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.chatbot](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.codebuild_terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.codepipeline_role_terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.codebuild_policy_terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.codepipeline_policy_terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.chatbot_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_bucket.pipeline_resources_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.pipeline_resources_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.pipeline_resources_bucket_pab](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.pipeline_resources_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.pipeline_resources_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_sns_topic.chatbot_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.access_from_chatbot](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_apply_tfvars"></a> [apply\_tfvars](#input\_apply\_tfvars) | The path for the TFVars Apply folder, this is the full relative path | `string` | `"./apply-tfvars"` | no |
| <a name="input_cb_accounts_map"></a> [cb\_accounts\_map](#input\_cb\_accounts\_map) | Map of environments, IAM assumption roles, AWS accounts to create pipeline stages for.cb\_accounts\_map = {dev = {account\_id = 123456789012; iam\_role = "stringrolename"}} | <pre>map(object(<br>    {<br>      account_id      = string<br>      iam_role        = string<br>      manual_approval = bool<br>      order           = number<br>    }<br>  ))</pre> | n/a | yes |
| <a name="input_cb_apply_timeout"></a> [cb\_apply\_timeout](#input\_cb\_apply\_timeout) | Maximum time in minutes to wait while applying terraform before killing the build. | `number` | `60` | no |
| <a name="input_cb_env_compute_type"></a> [cb\_env\_compute\_type](#input\_cb\_env\_compute\_type) | Size of instance to run Codebuild within. Valid Values are BUILD\_GENERAL1\_SMALL, BUILD\_GENERAL1\_MEDIUM, BUILD\_GENERAL1\_LARGE, BUILD\_GENERAL1\_2XLARGE. | `string` | `"BUILD_GENERAL1_SMALL"` | no |
| <a name="input_cb_env_image"></a> [cb\_env\_image](#input\_cb\_env\_image) | Identifies the Docker image to use for this build project. Available images documented in [the official AWS Codebuild documentation](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html). | `string` | `"aws/codebuild/standard:5.0"` | no |
| <a name="input_cb_env_image_pull_credentials_type"></a> [cb\_env\_image\_pull\_credentials\_type](#input\_cb\_env\_image\_pull\_credentials\_type) | The type of credentials AWS CodeBuild uses to pull images in your build. There are two valid values described in [the ProjectEnvironment documentation](https://docs.aws.amazon.com/codebuild/latest/APIReference/API_ProjectEnvironment.html). | `string` | `"CODEBUILD"` | no |
| <a name="input_cb_env_name"></a> [cb\_env\_name](#input\_cb\_env\_name) | Should be referenced from env\_name of calling terraform module. | `string` | n/a | yes |
| <a name="input_cb_env_type"></a> [cb\_env\_type](#input\_cb\_env\_type) | Codebuild Environment to use for stages in the pipeline. Valid Values are documented at [the ProjectEnvironment documentation](https://docs.aws.amazon.com/codebuild/latest/APIReference/API_ProjectEnvironment.html). | `string` | `"LINUX_CONTAINER"` | no |
| <a name="input_cb_gh_app_id"></a> [cb\_gh\_app\_id](#input\_cb\_gh\_app\_id) | ID of the GitHub App. | `string` | `""` | no |
| <a name="input_cb_gh_app_installation_id"></a> [cb\_gh\_app\_installation\_id](#input\_cb\_gh\_app\_installation\_id) | Installation ID of the GitHub App. | `string` | `""` | no |
| <a name="input_cb_gh_private_key_arn"></a> [cb\_gh\_private\_key\_arn](#input\_cb\_gh\_private\_key\_arn) | Secret's ARN containing the binary of the private key for the GitHub App. | `string` | `""` | no |
| <a name="input_cb_plan_timeout"></a> [cb\_plan\_timeout](#input\_cb\_plan\_timeout) | Maximum time in minutes to wait while generating terraform plan before killing the build. | `number` | `15` | no |
| <a name="input_cb_tf_version"></a> [cb\_tf\_version](#input\_cb\_tf\_version) | Version of terraform to download and install. Must match version scheme used for URL creation on terraform site. | `string` | n/a | yes |
| <a name="input_codebuild_iam_policy"></a> [codebuild\_iam\_policy](#input\_codebuild\_iam\_policy) | JSON string defining the initial/base codebuild IAM policy (must be passed in from caller). | `string` | n/a | yes |
| <a name="input_cp_resource_bucket_arn"></a> [cp\_resource\_bucket\_arn](#input\_cp\_resource\_bucket\_arn) | ARN of the S3 bucket where the source artifacts exist. | `string` | n/a | yes |
| <a name="input_cp_resource_bucket_key_name"></a> [cp\_resource\_bucket\_key\_name](#input\_cp\_resource\_bucket\_key\_name) | Prefix and key of the source artifact file. For instance, `source/master.zip`. | `string` | n/a | yes |
| <a name="input_cp_resource_bucket_kms_key_arn"></a> [cp\_resource\_bucket\_kms\_key\_arn](#input\_cp\_resource\_bucket\_kms\_key\_arn) | ARN of customer-manged KMS key used to encrypt objects in the source/resource bucket. Optional. | `string` | `""` | no |
| <a name="input_cp_resource_bucket_name"></a> [cp\_resource\_bucket\_name](#input\_cp\_resource\_bucket\_name) | Name of the S3 bucket where the source artifacts exist. | `string` | n/a | yes |
| <a name="input_cp_source_branch"></a> [cp\_source\_branch](#input\_cp\_source\_branch) | Repository branch to check out. Usually `master` or `main`. | `string` | n/a | yes |
| <a name="input_cp_source_codestar_connection_arn"></a> [cp\_source\_codestar\_connection\_arn](#input\_cp\_source\_codestar\_connection\_arn) | ARN of Codestar of GitHub/Bitbucket/etc connection which grants access to source repository. | `string` | `""` | no |
| <a name="input_cp_source_owner"></a> [cp\_source\_owner](#input\_cp\_source\_owner) | GitHub/Bitbucket organization username. | `string` | n/a | yes |
| <a name="input_cp_source_poll_for_changes"></a> [cp\_source\_poll\_for\_changes](#input\_cp\_source\_poll\_for\_changes) | Cause codepipeline to poll regularly for source code changes instead of waiting for CloudWatch Events. This is not required with a Codestar connection and should be avoided unless Codestar and webhooks are unavailable. | `bool` | `false` | no |
| <a name="input_cp_source_repo"></a> [cp\_source\_repo](#input\_cp\_source\_repo) | Name of repository to clone. | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Conditionally create resources. Affects nearly all resources. | `string` | `""` | no |
| <a name="input_init_tfvars"></a> [init\_tfvars](#input\_init\_tfvars) | The path for the TFVars Init folder, this is the full relative path. I.E ./init-tfvars | `string` | `"./init-tfvars"` | no |
| <a name="input_input_tags"></a> [input\_tags](#input\_input\_tags) | Map of tags to apply to all taggable resources. | `map(string)` | <pre>{<br>  "Provisioner": "Terraform"<br>}</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | Name to prepend to all resource names within module. | `string` | `"codepipline-module"` | no |
| <a name="input_slack_channel_id"></a> [slack\_channel\_id](#input\_slack\_channel\_id) | The chanel ID for slack workspace where notifications are sent | `string` | `"F123CCAB1A"` | no |
| <a name="input_slack_notification_for_approval"></a> [slack\_notification\_for\_approval](#input\_slack\_notification\_for\_approval) | When true - AWS chatbot service is created along with a lambda function to approve codepipeline manual approval stage | `bool` | `false` | no |
| <a name="input_slack_workspace_id"></a> [slack\_workspace\_id](#input\_slack\_workspace\_id) | The workspace ID for slack account to be used for notifications | `string` | `"T01T01ABC"` | no |
| <a name="input_source_control"></a> [source\_control](#input\_source\_control) | Which source control is being used? | `string` | n/a | yes |
| <a name="input_source_control_commit_paths"></a> [source\_control\_commit\_paths](#input\_source\_control\_commit\_paths) | Source Control URL Commit Paths Map | `map(map(string))` | <pre>{<br>  "BitBucket": {<br>    "path1": "https://bitbucket.org",<br>    "path2": "commits"<br>  },<br>  "GitHub": {<br>    "path1": "https://github.com",<br>    "path2": "commit"<br>  }<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_codepipeline_resources_bucket_arn"></a> [codepipeline\_resources\_bucket\_arn](#output\_codepipeline\_resources\_bucket\_arn) | n/a |

---

## Regarding CodeStar Connections for GitHub integration

A Codestar connection will be created in the "pending" state and must then be manually activated/confirmed in the management console. The ARN for the confirmed connection must be entered in the module variables to provide the necessary connection.

## Example CodeStar Connection resource

```hcl
resource "aws_codestarconnections_connection" "test_repo" {
name = "test-cicd-connection"
provider_type = "GitHub"
}
```

## Contributors
- Christopher Childress [chrischildresssg](https://github.com/chrischildresssg)
- Ivan Casco [ivancasco-sg](https://github.com/ivancasco-sg)
- Wesley Kirkland [wesleykirklandsg](https://github.com/wesleykirklandsg)
- Max Rahimi [maxr-sg](https://github.com/maxr-sg)

Note, manual changes to the README will be overwritten when the documentation is updated. To update the documentation, run `terraform-docs -c .config/.terraform-docs.yml .`
<!-- END_TF_DOCS -->