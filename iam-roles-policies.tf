### CODEBUILD TERRAFORM IAM ROLE ###
resource "aws_iam_role" "codebuild_terraform" {
  name               = "${var.name}-build"
  count              = var.create ? 1 : 0
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "codebuild_policy_terraform" {
  name   = "${var.name}-build"
  count  = var.create ? 1 : 0
  role   = join("", aws_iam_role.codebuild_terraform.*.id)
  policy = var.codebuild_iam_policy
}



### CODEPIPELINE TERRAFORM IAM ROLE ###
resource "aws_iam_role" "codepipeline_role_terraform" {
  name               = "${var.name}-codepipeline"
  count              = var.create ? 1 : 0
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "codepipeline_policy_terraform" {
  dynamic "statement" {
    for_each = var.cp_resource_bucket_name != "" ? [true] : []
    content {
      sid = "CodeBucketAccess"

      actions = [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning"
      ]

      resources = [
        var.cp_resource_bucket_arn,
        "${var.cp_resource_bucket_arn}/*"
      ]
    }
  }

  dynamic "statement" {
    for_each = var.cp_source_codestar_connection_arn != "" ? [true] : []
    content {
      sid = "CodeStarConnectionAccess"

      actions = [
        "codestar-connections:PassConnection",
        "codestar-connections:UseConnection"
      ]

      resources = [var.cp_source_codestar_connection_arn]
    }
  }

  statement {
    sid = "PipelineBucketAccess"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]

    resources = [
      aws_s3_bucket.pipeline_resources_bucket.arn,
      "${aws_s3_bucket.pipeline_resources_bucket.arn}/*"
    ]
  }

  statement {
    sid = "CodebuildBuildRights"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]

    resources = ["*"]
  }

  statement {
    sid = "KMSAccess"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = [
      data.aws_kms_alias.s3.arn
    ]
  }

  statement {
    sid = "CodeDeployAccess"

    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision"
    ]

    resources = ["*"]
  }

}

resource "aws_iam_role_policy" "codepipeline_policy_terraform" {
  name   = "${var.name}-codepipeline-policy"
  role   = join("", aws_iam_role.codepipeline_role_terraform.*.id)
  count  = var.create ? 1 : 0
  policy = data.aws_iam_policy_document.codepipeline_policy_terraform.json
}
