data "aws_kms_alias" "s3" {
  name = "alias/aws/s3"
}
resource "aws_codepipeline" "codepipeline_terraform" {
  #lifecycle {
  #  ignore_changes = [stage[0].action[0].configuration]
  #}
  count    = var.create ? 1 : 0
  name     = "${var.name}-cp-terraform"
  role_arn = join("", aws_iam_role.codepipeline_role_terraform.*.arn)

  artifact_store {
    location = aws_s3_bucket.pipeline_resources_bucket.bucket
    type     = "S3"
    encryption_key {
      id   = data.aws_kms_alias.s3.arn
      type = "KMS"
    }
  }
  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.name}-cp-terraform"
    },
  )
  stage {
    # TODO: Dynamic to support for S3 and codestar
    name = "Source"

    action {
      owner            = "AWS"
      name             = "ArtifactsS3"
      category         = "Source"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        PollForSourceChanges = "false"
        S3Bucket    = var.cp_resource_bucket_name
        S3ObjectKey = var.cp_resource_bucket_key_name
      }
    }
//    action {
//      name             = "Source"
//      category         = "Source"
//      owner            = "AWS"
//      provider         = "CodeStarSourceConnection"
//      version          = "1"
//      output_artifacts = ["source_output"]
//      namespace        = "SourceVariables"
//
//      configuration = {
//        BranchName           = var.cp_source_branch
//        FullRepositoryId     = "${var.cp_source_owner}/${var.cp_source_repo}"
//        ConnectionArn        = var.cp_source_codestar_connection_arn
//        OutputArtifactFormat = "CODE_ZIP"
//      }
//    }
  }

  dynamic "stage" {
    for_each = var.environment_names
    content {
      name = "${upper(stage.value)}-Plan-and-Apply"

      action {
        name             = "Plan"
        category         = "Build"
        owner            = "AWS"
        provider         = "CodeBuild"
        input_artifacts  = ["source_output"]
        output_artifacts = ["${stage.value}_plan_output"]
        namespace        = "${stage.value}_variables"
        version          = "1"
        run_order        = 1

        configuration = {
          ProjectName = join("", aws_codebuild_project.terraform_plan.*.name)
          EnvironmentVariables = jsonencode(
            [
              {
                name  = "TERRAFORM_ENVIRONMENT_NAME"
                type  = "PLAINTEXT"
                value = stage.value
              },
              {
                name  = "TERRAFORM_ASSUME_ROLE"
                type  = "PLAINTEXT"
                value = var.cb_iam_role
              },
              {
                name  = "TERRAFORM_ACCOUNT_ID",
                type  = "PLAINTEXT"
                value = var.cb_accounts_map[stage.value]["account_id"]
              }
            ]
          )
        }
      }

      dynamic "action" {
        for_each = contains(var.cp_tf_manual_approval, stage.value) ? [true] : []
        content {
          name     = "Approval"
          category = "Approval"
          owner    = "AWS"
          provider = "Manual"
//          configuration = {
//            CustomData         = "Please review the codebuild output and verify the changes. Commit ID: #{SourceVariables.CommitId}"
//            ExternalEntityLink = "https://github.com/${var.cp_source_owner}/${var.cp_source_repo}/commit/#{SourceVariables.CommitId}"
//          }
          input_artifacts  = []
          output_artifacts = []
          version          = "1"
          run_order        = 2
        }
      }

      action {
        name     = "Apply"
        category = "Build"
        owner    = "AWS"
        provider = "CodeBuild"
        input_artifacts = ["${stage.value}_plan_output"]
        version         = "1"
        run_order       = 3
        configuration = {
          ProjectName   = join("", aws_codebuild_project.terraform_apply.*.name)
          PrimarySource = "${stage.value}_plan_output"
          EnvironmentVariables = jsonencode(
            [
              {
                name  = "TERRAFORM_ENVIRONMENT_NAME"
                type  = "PLAINTEXT"
                value = stage.value
              },
              {
                name  = "TERRAFORM_ASSUME_ROLE"
                type  = "PLAINTEXT"
                value = stage.value
              },
              {
                name  = "TERRAFORM_ACCOUNT_ID",
                type  = "PLAINTEXT"
                value = var.cb_accounts_map[stage.value]["account_id"]
              }
            ]
          )
        }
      }
    }
  }
}
