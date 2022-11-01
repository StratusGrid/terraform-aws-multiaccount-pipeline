resource "aws_codebuild_project" "terraform_plan" {
  name          = "${var.name}-tf-plan"
  count         = var.create ? 1 : 0
  description   = "terraform codebuild plan project"
  build_timeout = var.cb_plan_timeout
  service_role  = join("", aws_iam_role.codebuild_terraform[*].arn)

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
    dynamic "environment_variable" {
      for_each = var.cb_gh_app_id != "" ? [true] : []
      content {
        name  = "GITHUB_APP_ID"
        value = var.cb_gh_app_id
      }
    }
    dynamic "environment_variable" {
      for_each = var.cb_gh_app_installation_id != "" ? [true] : []
      content {
        name  = "GITHUB_APP_INSTALLATION_ID"
        value = var.cb_gh_app_installation_id
      }
    }
    dynamic "environment_variable" {
      for_each = var.cb_gh_private_key_arn != "" ? [true] : []
      content {
        name  = "GITHUB_APP_KEY_ARN"
        value = var.cb_gh_private_key_arn
      }
    }
    environment_variable {
      name  = "GITHUB_OWNER"
      value = var.cp_source_owner
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
      %{if var.cb_gh_app_id != ""}- curl -o ghtoken -O -L -C  - https://raw.githubusercontent.com/Link-/gh-token/main/gh-token && echo "6a6b111355432e08dd60ac0da148e489cdb0323a059ee8cbe624fd37bf2572ae  ghtoken" | shasum -c - && chmod u+x ./ghtoken%{else}- echo No GitHub App in use. Skipping...%{endif}
  pre_build:
    commands:
      - |
        eval `aws sts assume-role --role-arn arn:aws:iam::$${TERRAFORM_ACCOUNT_ID}:role/$${TERRAFORM_ASSUME_ROLE} --role-session-name terraform-codebuild-${var.cb_env_name} \
        | jq -r '"export AWS_ACCESS_KEY_ID=" + .Credentials.AccessKeyId, "export AWS_SECRET_ACCESS_KEY="+.Credentials.SecretAccessKey, "export AWS_SESSION_TOKEN="+.Credentials.SessionToken'`
      %{if var.cb_gh_private_key_arn != ""}- aws secretsmanager get-secret-value --secret-id $${GITHUB_APP_KEY_ARN} --query SecretString --output text | jq .pem_file --raw-output | base64 --decode > app_private_key.pem%{else}- echo GitHub App key not in use.%{endif}
      %{if var.cb_gh_app_installation_id != ""}- export GH_TOKEN=$(./ghtoken generate --key app_private_key.pem --app_id $${GITHUB_APP_ID} --installation_id $${GITHUB_APP_INSTALLATION_ID} --install_jwt_cli | jq .token --raw-output)%{else}- echo GitHub App installation token not needed.%{endif}
      %{if var.cb_gh_app_id != ""}- git config --global url."https://x-access-token:$GH_TOKEN@github.com".insteadOf "https://github.com"%{else}- echo No git config is needed. Skipping...%{endif}
      - terraform init -backend-config=${var.init_tfvars}/$${TERRAFORM_ENVIRONMENT_NAME}.tfvars
  build:
    commands:
      - echo Build started on `date`
      - terraform plan -out=tfplan -var-file=${var.apply_tfvars}/$${TERRAFORM_ENVIRONMENT_NAME}.tfvars
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
    local.common_tags,
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
  service_role  = join("", aws_iam_role.codebuild_terraform[*].arn)

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
    dynamic "environment_variable" {
      for_each = var.cb_gh_app_id != "" ? [true] : []
      content {
        name  = "GITHUB_APP_ID"
        value = var.cb_gh_app_id
      }
    }
    dynamic "environment_variable" {
      for_each = var.cb_gh_app_installation_id != "" ? [true] : []
      content {
        name  = "GITHUB_APP_INSTALLATION_ID"
        value = var.cb_gh_app_installation_id
      }
    }
    dynamic "environment_variable" {
      for_each = var.cb_gh_private_key_arn != "" ? [true] : []
      content {
        name  = "GITHUB_APP_KEY_ARN"
        value = var.cb_gh_private_key_arn
      }
    }
    environment_variable {
      name  = "GITHUB_OWNER"
      value = var.cp_source_owner
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
      %{if var.cb_gh_app_id != ""}- curl -o ghtoken -O -L -C  - https://raw.githubusercontent.com/Link-/gh-token/main/gh-token && echo "6a6b111355432e08dd60ac0da148e489cdb0323a059ee8cbe624fd37bf2572ae  ghtoken" | shasum -c - && chmod u+x ./ghtoken%{else}- echo No GitHub App in use. Skipping...%{endif}
  pre_build:
    commands:
      - |
        eval `aws sts assume-role --role-arn arn:aws:iam::$${TERRAFORM_ACCOUNT_ID}:role/$${TERRAFORM_ASSUME_ROLE} --role-session-name terraform-codebuild-${var.cb_env_name} \
        | jq -r '"export AWS_ACCESS_KEY_ID=" + .Credentials.AccessKeyId, "export AWS_SECRET_ACCESS_KEY=" + .Credentials.SecretAccessKey, "export AWS_SESSION_TOKEN=" + .Credentials.SessionToken'`
      %{if var.cb_gh_private_key_arn != ""}- aws secretsmanager get-secret-value --secret-id $${GITHUB_APP_KEY_ARN} --query SecretString --output text | jq .pem_file --raw-output | base64 --decode > app_private_key.pem%{else}- echo GitHub App key not in use.%{endif}
      %{if var.cb_gh_app_installation_id != ""}- export GH_TOKEN=$(./ghtoken generate --key app_private_key.pem --app_id $${GITHUB_APP_ID} --installation_id $${GITHUB_APP_INSTALLATION_ID} --install_jwt_cli | jq .token --raw-output)%{else}- echo GitHub App installation token not needed.%{endif}
      %{if var.cb_gh_app_id != ""}- git config --global url."https://x-access-token:$GH_TOKEN@github.com".insteadOf "https://github.com"%{else}- echo No git config is needed. Skipping...%{endif}
      - terraform init -backend-config=${var.init_tfvars}/$${TERRAFORM_ENVIRONMENT_NAME}.tfvars
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
    local.common_tags,
    {
      "Name" = "${var.name}-tf-apply"
    },
  )
}
