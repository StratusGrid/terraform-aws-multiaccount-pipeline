# terraform-iac-pipeline

This repository lets you create a codepipeline and supporting codebuilds etc. for automatically deploying terraform code.

NOTE: Due to a bug in Terraform, we must ignore_changes on the github configuration to prevent it attempting to update oauthtoken every apply. If this ever needs to be updated, this can be destroying the pipeline and letting it be remade, or by removing the the following code block from te codepipeline-terraform.tf file:
```
  lifecycle {
    ignore_changes = [stage[0].action[0].configuration]
  }
```

### Example:
```
module "cloudfront_codepipeline" {
  source                = "github.com/StratusGrid/terraform-aws-codepipeline-iac"
  name                  = "${var.name_prefix}-unique-name${local.name_suffix}"
  cp_tf_manual_approval = [true] # leave array empty to not have a manual approval step
  codebuild_iam_policy  = local.cloudfront_codebuild_policy
  cb_env_compute_type   = "BUILD_GENERAL1_SMALL"
  cb_env_image          = "aws/codebuild/standard:2.0"
  cb_env_type           = "LINUX_CONTAINER"
  cb_tf_version         = "0.12.24"
  cb_env_name           = var.env_name
  cp_source_oauth_token = "jsdgsidg7hisldhsidf79we7rw724r927hr2"
  cp_source_owner       = "my-org"
  cp_source_repo        = "my-repo"
  cp_source_branch      = var.env_name

  cb_env_image_pull_credentials_type = "CODEBUILD"
  cp_source_poll_for_changes         = true
}

locals {
  cloudfront_codebuild_policy = <<POLICY
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
            "Resource": "arn:aws:s3:::${var.backend_name}/funicom-delivery-static-${var.env_name}.tfstate"
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
                "${module.cloudfront_codepipeline.codepipeline_resources_bucket_arn}",
                "${module.cloudfront_codepipeline.codepipeline_resources_bucket_arn}/*"
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
                "cloudfront:*",
                "s3:*",
                "lambda:*",
                "apigateway:*"
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