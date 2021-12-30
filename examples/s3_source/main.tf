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
