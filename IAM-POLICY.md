Below is an example policy of what to add to thge child accounts for the multi account pipeline to assume and have the correct permissions to acomplish it's role.

```hcl
data "aws_iam_policy_document" "this" {
  statement {
    sid = "AllowFullAdminExceptSomeWithMFA"
    not_actions = [
      "logs:Delete*",
      "cloudtrail:Delete*",
      "cloudtrail:Stop*",
      "cloudtrail:Update*",
      "sts:AssumeRoleWithSAML",
      "sts:AssumeRoleWithWebIdentity",
      "sts:GetFederationToken",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "cicd" {
  name        = "CICD-policy"
  description = "Policy to grant restricted admin. This admin can't do some functions such as delete the CloudTrail audit trail."
  policy      = data.aws_iam_policy_document.this.json
}


module "iam_role_cicd" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"

  trusted_role_arns = [
    "arn:aws:iam::467176576189:root" # Root means account and not root user
  ]

  create_role = true

  role_name         = "${var.name_prefix}-pipeline-role-CICD" #The assuming account matches it based upon name
  role_requires_mfa = false

  custom_role_policy_arns = [
    //aws_iam_role_policy.codepipeline_deploy_policy.arn
    aws_iam_policy.cicd.arn
  ]

  tags = {
    "Name" = "${var.name_prefix}-pipeline-role-CICD${local.name_suffix}"
  }
}
```