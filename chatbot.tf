############## IAM Roles #######################
resource "aws_iam_role" "chatbot" {
  count = var.slack_notification_for_approval == true ? 1 : 0
  name  = "${var.name}-chatbot-role${local.name_suffix}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "chatbot.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = local.common_tags
}

data "aws_iam_policy_document" "chatbot_policy_doc" {

  statement {
    sid    = "AllowCloudWatch"
    effect = "Allow"

    actions = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "LambdaInvoke"
    effect = "Allow"

    actions = [
      "lambda:invokeAsync",
      "lambda:invokeFunction"
    ]

    resources = ["*"]
  }

}

data "aws_iam_policy_document" "sns_topic_policy" {
  count     = var.slack_notification_for_approval == true ? 1 : 0
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "sns:Publish"
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codestar-notifications.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.chatbot_sns[0].arn,
    ]

    sid = "__default_statement_ID"
  }
}

resource "aws_iam_policy" "chatbot_policy" {
  count       = var.slack_notification_for_approval == true ? 1 : 0
  name        = "${var.name}-chatbot-policy${local.name_suffix}"
  path        = "/"
  description = "Policy for AWS Chatbot Service"
  policy      = data.aws_iam_policy_document.chatbot_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "chatbot_policy_attachment" {
  count      = var.slack_notification_for_approval == true ? 1 : 0
  role       = aws_iam_role.chatbot[0].name
  policy_arn = aws_iam_policy.chatbot_policy[0].arn
}


################## Chatbot SNS Topic ###################################
resource "aws_sns_topic" "chatbot_sns" {
  count = var.slack_notification_for_approval == true ? 1 : 0
  name  = "${var.name}-SNS-Topic${local.name_suffix}"

  delivery_policy = <<EOF
  {
    "http": {
      "defaultHealthyRetryPolicy": {
        "minDelayTarget": 20,
        "maxDelayTarget": 20,
        "numRetries": 3,
        "numMaxDelayRetries": 0,
        "numNoDelayRetries": 0,
        "numMinDelayRetries": 0,
        "backoffFunction": "linear"
      },
      "disableSubscriptionOverrides": false
    }
  }
EOF

}

resource "aws_sns_topic_policy" "access_from_chatbot" {
  count = var.slack_notification_for_approval == true ? 1 : 0
  arn   = aws_sns_topic.chatbot_sns[0].arn

  policy = data.aws_iam_policy_document.sns_topic_policy[0].json
}


################## Chatbot Service #####################################
locals {
  chatbot_logging_level      = "ERROR"
  chatbot_slack_workspace_id = var.slack_workspace_id
}

module "chatbot_slack_configuration" {
  source     = "waveaccounting/chatbot-slack-configuration/aws"
  version    = "1.1.0"
  count      = var.slack_notification_for_approval == true ? 1 : 0
  depends_on = [aws_sns_topic.chatbot_sns]

  configuration_name = "${var.name}-Chatbot-Service${local.name_suffix}"
  iam_role_arn       = aws_iam_role.chatbot[0].arn
  slack_channel_id   = var.slack_channel_id
  slack_workspace_id = local.chatbot_slack_workspace_id
  guardrail_policies = [aws_iam_policy.chatbot_policy[0].arn]

  sns_topic_arns = [
    aws_sns_topic.chatbot_sns[0].arn,
  ]

  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.name}-Chatbot-Service"
    },
  )
}

################# Lambda Function ######################################
module "lambda_function" {
  source        = "terraform-aws-modules/lambda/aws"
  count         = var.slack_notification_for_approval == true ? 1 : 0
  function_name = "${var.name}-codepipeline-approval"
  description   = "Lambda Function approves codepipeline manual approval via slack"
  handler       = "main.lambda_handler"
  runtime       = "python3.8"
  timeout       = 30

  source_path = "${path.module}/src/main.py"

  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.name}-codepipeline-approval${local.name_suffix}"
    },
  )

  attach_policy_statements = true
  policy_statements = {
    CodePipeline = {
      effect    = "Allow",
      actions   = ["codepipeline:List*", "codepipeline:Get*", "codepipeline:PutApprovalResult"],
      resources = ["*"]
    }
  }
  environment_variables = {
    pipelineName = aws_codepipeline.codepipeline_terraform[0].name
  }
}

################### Codestar Notifications ##############################
resource "aws_codestarnotifications_notification_rule" "plan_stats" {
  count       = var.slack_notification_for_approval == true ? 1 : 0
  detail_type = "FULL"
  event_type_ids = [
    "codebuild-project-build-state-succeeded",
    "codebuild-project-build-state-failed",
    "codebuild-project-build-state-in-progress"

  ]

  name     = "${var.name}-codebuild-tf-plan-rule${local.name_suffix}"
  resource = aws_codebuild_project.terraform_plan[0].arn

  target {
    address = module.chatbot_slack_configuration[0].configuration_arn
    type    = "AWSChatbotSlack"
  }
}

resource "aws_codestarnotifications_notification_rule" "apply_stats" {
  count       = var.slack_notification_for_approval == true ? 1 : 0
  detail_type = "FULL"
  event_type_ids = [
    "codebuild-project-build-state-succeeded",
    "codebuild-project-build-state-failed",
    "codebuild-project-build-state-in-progress"
  ]

  name     = "${var.name}-codebuild-tf-apply-rule${local.name_suffix}"
  resource = aws_codebuild_project.terraform_apply[0].arn

  target {
    address = module.chatbot_slack_configuration[0].configuration_arn
    type    = "AWSChatbotSlack"
  }
}

resource "aws_codestarnotifications_notification_rule" "approval_needed" {
  count       = var.slack_notification_for_approval == true ? 1 : 0
  detail_type = "FULL"
  event_type_ids = [
    "codepipeline-pipeline-manual-approval-needed",
  ]

  name     = "${var.name}-codepipeline-manual-approval-rule${local.name_suffix}"
  resource = aws_codepipeline.codepipeline_terraform[0].arn

  target {
    address = module.chatbot_slack_configuration[0].configuration_arn
    type    = "AWSChatbotSlack"
  }
}