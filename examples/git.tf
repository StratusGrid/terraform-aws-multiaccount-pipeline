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
  
  //This is part of an or statement, this section is meant for if your artifacts are local and not in GIT. Use whitespace to emulate nulls, they must still be defined.
  cp_resource_bucket_arn             = ""
  cp_resource_bucket_name            = ""
  cp_resource_bucket_key_name        = ""
  cp_source_poll_for_changes         = true

  //This is used to enable slack notifications for codebuild statuses as well as codepipeline manual approval via AWS chatbot service 
  slack_notification_for_approval    = true
  slack_workspace_id                 = ""
  slack_channel_id                   = ""
  
  //Each environment but be in the order, we prefix this list since the map will sort alphabetically and we can not change that.
  //We make an assumption that the environment name matches the environment name in the TF init and apply directories.
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