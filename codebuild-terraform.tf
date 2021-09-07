resource "aws_codebuild_project" "terraform_plan" {
  name          = "${var.name}-tf-plan"
  count         = var.create ? 1 : 0
  description   = "terraform codebuild plan project"
  build_timeout = var.cb_plan_timeout
  service_role  = join("", aws_iam_role.codebuild_terraform.*.arn)

  environment {
    compute_type                = var.cb_env_compute_type
    image                       = var.cb_env_image
    type                        = var.cb_env_type
    image_pull_credentials_type = var.cb_env_image_pull_credentials_type

    environment_variable {
      name  = "TERRAFORM_VERSION"
      value = var.cb_tf_version
    }
    environment_variable {
      name  = "TF_CLI_ARGS"
      value = "-no-color -input=false"
    }
    environment_variable {
      name  = "TF_IN_AUTOMATION"
      value = "true"
    }
  }
  artifacts {
    type                = "CODEPIPELINE"
    artifact_identifier = "plan_output"
  }
  source {
    type      = "CODEPIPELINE" # TODO: variabilize role name.
    buildspec = <<BUILDSPEC
version: 0.2

phases:
  install:
    runtime-versions:
      python: 3.x
    commands:
      - echo Terraform environment name $${TERRAFORM_ENVIRONMENT_NAME}
      - wget -q https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip
      - unzip ./terraform_$${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/
      - rm terraform_$${TERRAFORM_VERSION}_linux_amd64.zip
  pre_build:
    commands:
      - |
        eval `aws sts assume-role --role-arn arn:aws:iam::$${TERRAFORM_ACCOUNT_ID}:role/$${TERRAFORM_ASSUME_ROLE} --role-session-name terraform-codebuild-${var.cb_env_name} \
        | jq -r '"export AWS_ACCESS_KEY_ID=" + .Credentials.AccessKeyId, "export AWS_SECRET_ACCESS_KEY="+.Credentials.SecretAccessKey, "export AWS_SESSION_TOKEN="+.Credentials.SessionToken'`
      - terraform init -backend-config=./init-tfvars/$${TERRAFORM_ENVIRONMENT_NAME}.tfvars
  build:
    commands:
      - echo Build started on `date`
      - terraform plan -out=tfplan -var-file=./apply-tfvars/$${TERRAFORM_ENVIRONMENT_NAME}.tfvars
  post_build:
    commands:
      - echo Entered the post_build phase...
      - echo Build completed on `date`
artifacts:
  name: plan_output
  files:
    - '**/*'
BUILDSPEC
  }
  tags = merge(
    var.input_tags,
    {
      "Name" = "${var.name}-tf-plan"
    },
  )
}


resource "aws_codebuild_project" "terraform_apply" {
  name          = "${var.name}-tf-apply"
  count         = var.create ? 1 : 0
  description   = "terraform codebuild apply project"
  build_timeout = var.cb_apply_timeout
  service_role  = join("", aws_iam_role.codebuild_terraform.*.arn)

  environment {
    compute_type                = var.cb_env_compute_type
    image                       = var.cb_env_image
    type                        = var.cb_env_type
    image_pull_credentials_type = var.cb_env_image_pull_credentials_type

    environment_variable {
      name  = "TERRAFORM_VERSION"
      value = var.cb_tf_version
    }
    environment_variable {
      name  = "TF_CLI_ARGS"
      value = "-no-color -input=false"
    }
    environment_variable {
      name  = "TF_IN_AUTOMATION"
      value = "true"
    }
  }
  artifacts {
    type = "CODEPIPELINE"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = <<BUILDSPEC
version: 0.2

phases:
  install:
    runtime-versions:
      python: 3.x
    commands:
      - wget -q https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip
      - unzip ./terraform_$${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/
      - rm terraform_$${TERRAFORM_VERSION}_linux_amd64.zip
  pre_build:
    commands:
      - |
        eval `aws sts assume-role --role-arn arn:aws:iam::$${TERRAFORM_ACCOUNT_ID}:role/$${TERRAFORM_ASSUME_ROLE} --role-session-name terraform-codebuild-${var.cb_env_name} \
        | jq -r '"export AWS_ACCESS_KEY_ID=" + .Credentials.AccessKeyId, "export AWS_SECRET_ACCESS_KEY=" + .Credentials.SecretAccessKey, "export AWS_SESSION_TOKEN=" + .Credentials.SessionToken'`
      - terraform init -backend-config=./init-tfvars/$${TERRAFORM_ENVIRONMENT_NAME}.tfvars
  build:
    commands:
      - echo Build started on `date`
      - terraform apply -input=false tfplan
  post_build:
    commands:
      - echo Entered the post_build phase...
      - echo Build completed on `date`
BUILDSPEC
  }
  tags = merge(
    var.input_tags,
    {
      "Name" = "${var.name}-tf-apply"
    },
  )
}
