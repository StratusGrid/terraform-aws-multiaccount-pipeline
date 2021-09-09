<!-- BEGIN_TF_DOCS -->
# Terraform Multiaccount Pipeline

[StratusGrid/terraform-aws-multiaccount-pipeline](https://github.com/StratusGrid/terraform-aws-multiaccount-pipeline)

Terraform module to create a CICD pipeline for Terraform which can execute from a Production or CICD account across multiple sub-accounts which each contain a specific environment.

---

## Example with S3 bucket source

```hcl
module "terraform_pipeline" {
  source                             = "../.."
  create                             = true
  name                               = "${var.name_prefix}-utils${local.name_suffix}"
  environment_names                  = ["dev", "qa", "prd"] # List of envs being deployed
  cp_tf_manual_approval              = ["qa", "prd"] # List of envs enabled for manual approval
  codebuild_iam_policy               = local.terraform_pipeline_codebuild_policy
  cb_env_compute_type                = "BUILD_GENERAL1_SMALL"
  cb_env_image                       = "aws/codebuild/standard:4.0"
  cb_env_type                        = "LINUX_CONTAINER"
  cb_iam_role                        = "${var.name_prefix}-pipeline-role-${var.env_name}" # This is what provides cross-account access. Ensure this role exists in each account and is assumable by CodeBuild in the account which runs the pipeline.
  cb_tf_version                      = "0.14.11"
  cb_env_name                        = var.env_name
  cp_source_owner                    = ""
  cp_source_repo                     = ""
  cp_source_branch                   = "master"
  cb_env_image_pull_credentials_type = "CODEBUILD"
  cp_resource_bucket_arn             = aws_s3_bucket.utils_resource_bucket.arn
  cp_resource_bucket_name            = aws_s3_bucket.utils_resource_bucket.bucket
  cp_resource_bucket_key_name        = "source_artifacts/master.zip"
  cp_source_poll_for_changes         = true
  cb_accounts_map = {
    dev = {
      account_id = "1234567890" 
    }
    qa = {
      account_id = "2345678901"
    }
    prd = {
      account_id = "3456789012"
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
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.55 |

## Resources

| Name | Type |
|------|------|
| [aws_codebuild_project.terraform_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) | resource |
| [aws_codebuild_project.terraform_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) | resource |
| [aws_codepipeline.codepipeline_terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline) | resource |
| [aws_iam_role.codebuild_terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.codepipeline_role_terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.codebuild_policy_terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.codepipeline_policy_terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_s3_bucket.pipeline_resources_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.pipeline_resources_bucket_pab](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cb_accounts_map"></a> [cb\_accounts\_map](#input\_cb\_accounts\_map) | Map of environments and AWS accounts to create pipeline stages for. | `map(map(string))` | n/a | yes |
| <a name="input_cb_apply_timeout"></a> [cb\_apply\_timeout](#input\_cb\_apply\_timeout) | Maximum time in minutes to wait while applying terraform before killing the build. | `number` | `60` | no |
| <a name="input_cb_env_compute_type"></a> [cb\_env\_compute\_type](#input\_cb\_env\_compute\_type) | Size of instance to run Codebuild within. Valid Values are BUILD\_GENERAL1\_SMALL, BUILD\_GENERAL1\_MEDIUM, BUILD\_GENERAL1\_LARGE, BUILD\_GENERAL1\_2XLARGE. | `string` | `"BUILD_GENERAL1_SMALL"` | no |
| <a name="input_cb_env_image"></a> [cb\_env\_image](#input\_cb\_env\_image) | Identifies the Docker image to use for this build project. Available images documented in [the official AWS Codebuild documentation](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html). | `string` | `"aws/codebuild/standard:4.0"` | no |
| <a name="input_cb_env_image_pull_credentials_type"></a> [cb\_env\_image\_pull\_credentials\_type](#input\_cb\_env\_image\_pull\_credentials\_type) | The type of credentials AWS CodeBuild uses to pull images in your build. There are two valid values described in [the ProjectEnvironment documentation](https://docs.aws.amazon.com/codebuild/latest/APIReference/API_ProjectEnvironment.html). | `string` | `"CODEBUILD"` | no |
| <a name="input_cb_env_name"></a> [cb\_env\_name](#input\_cb\_env\_name) | Should be referenced from env\_name of calling terraform module. | `string` | n/a | yes |
| <a name="input_cb_env_type"></a> [cb\_env\_type](#input\_cb\_env\_type) | Codebuild Environment to use for stages in the pipeline. Valid Values are documented at [the ProjectEnvironment documentation](https://docs.aws.amazon.com/codebuild/latest/APIReference/API_ProjectEnvironment.html). | `string` | `"LINUX_CONTAINER"` | no |
| <a name="input_cb_iam_role"></a> [cb\_iam\_role](#input\_cb\_iam\_role) | Cross-account IAM role to assume for Terraform. This role must be created in each account that is to be affected and must be RESTRICTED ADMIN within that account to have all necessary rights. The CodeBuild service within the account which runs the pipeline and builds must be able to assume this role. | `string` | n/a | yes |
| <a name="input_cb_plan_timeout"></a> [cb\_plan\_timeout](#input\_cb\_plan\_timeout) | Maximum time in minutes to wait while generating terraform plan before killing the build. | `number` | `15` | no |
| <a name="input_cb_tf_version"></a> [cb\_tf\_version](#input\_cb\_tf\_version) | Version of terraform to download and install. Must match version scheme used for URL creation on terraform site. | `string` | n/a | yes |
| <a name="input_codebuild_iam_policy"></a> [codebuild\_iam\_policy](#input\_codebuild\_iam\_policy) | JSON string defining the initial/base codebuild IAM policy (must be passed in from caller). | `string` | n/a | yes |
| <a name="input_cp_resource_bucket_arn"></a> [cp\_resource\_bucket\_arn](#input\_cp\_resource\_bucket\_arn) | ARN of the S3 bucket where the source artifacts exist. | `string` | n/a | yes |
| <a name="input_cp_resource_bucket_key_name"></a> [cp\_resource\_bucket\_key\_name](#input\_cp\_resource\_bucket\_key\_name) | Prefix and key of the source artifact file. For instance, `source/master.zip`. | `string` | n/a | yes |
| <a name="input_cp_resource_bucket_name"></a> [cp\_resource\_bucket\_name](#input\_cp\_resource\_bucket\_name) | Name of the S3 bucket where the source artifacts exist. | `string` | n/a | yes |
| <a name="input_cp_source_branch"></a> [cp\_source\_branch](#input\_cp\_source\_branch) | Repository branch to check out. Usually `master` or `main`. | `string` | n/a | yes |
| <a name="input_cp_source_codestar_connection_arn"></a> [cp\_source\_codestar\_connection\_arn](#input\_cp\_source\_codestar\_connection\_arn) | ARN of Codestar GitHub connection which grants access to source repository. | `string` | `""` | no |
| <a name="input_cp_source_owner"></a> [cp\_source\_owner](#input\_cp\_source\_owner) | GitHub user account name. | `string` | n/a | yes |
| <a name="input_cp_source_poll_for_changes"></a> [cp\_source\_poll\_for\_changes](#input\_cp\_source\_poll\_for\_changes) | Cause codepipeline to poll regularly for source code changes instead of waiting for CloudWatch Events. This is not required with a Codestar connection and should be avoided unless Codestar and webhooks are unavailable. | `bool` | `false` | no |
| <a name="input_cp_source_repo"></a> [cp\_source\_repo](#input\_cp\_source\_repo) | Name of repository to clone. | `string` | n/a | yes |
| <a name="input_cp_tf_manual_approval"></a> [cp\_tf\_manual\_approval](#input\_cp\_tf\_manual\_approval) | List of environments for which the terraform pipeline requires manual approval prior to application stage. | `list(any)` | `[]` | no |
| <a name="input_create"></a> [create](#input\_create) | Conditionally create resources. Affects nearly all resources. | `string` | `""` | no |
| <a name="input_environment_names"></a> [environment\_names](#input\_environment\_names) | List of names of all the environments to create pipeline stages for. | `list(string)` | <pre>[<br>  "PRD"<br>]</pre> | no |
| <a name="input_input_tags"></a> [input\_tags](#input\_input\_tags) | Map of tags to apply to all taggable resources. | `map(string)` | <pre>{<br>  "Provisioner": "Terraform"<br>}</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | Name to prepend to all resource names within module. | `string` | `"codepipline-module"` | no |

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

Note, manual changes to the README will be overwritten when the documentation is updated. To update the documentation, run `terraform-docs -c .config/.terraform-docs.yml .`
<!-- END_TF_DOCS -->