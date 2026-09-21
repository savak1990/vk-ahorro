terraform {
  backend "s3" {
    bucket         = "ahorro-app-state"
    key            = "pipeline/ahorro-ui/android/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "ahorro-app-state-lock"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Project   = "ahorro-app"
      Service   = "ahorro-ui-android-pipeline"
      Terraform = "true"
    }
  }
}

data "aws_secretsmanager_secret" "ahorro_app" {
  name = local.secret_name
}

data "aws_secretsmanager_secret_version" "ahorro_app" {
  secret_id = data.aws_secretsmanager_secret.ahorro_app.id
}

locals {
  project_name       = "ahorro-ui-android"
  codebuild_name     = "${local.project_name}-build"
  github_owner       = "savak1990"
  github_repo        = "ahorro-ui"
  github_branch      = "main"
  artifact_bucket    = "ahorro-artifacts"
  secret_name        = "ahorro-app-secrets"
  github_oauth_token = jsondecode(data.aws_secretsmanager_secret_version.ahorro_app.secret_string)["github_token"]
}

resource "aws_codebuild_project" "flutter_build" {
  name         = local.codebuild_name
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type                = "S3"
    location            = local.artifact_bucket
    path                = "ahorro-ui/android"
    packaging           = "ZIP"
    name                = "build-ahorro-android.zip"
    encryption_disabled = true
  }

  environment {
    compute_type    = "BUILD_GENERAL1_MEDIUM"
    image           = "instrumentisto/flutter:latest"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type                = "GITHUB"
    location            = "https://github.com/${local.github_owner}/${local.github_repo}.git"
    git_clone_depth     = 1
    buildspec           = "pipeline/android/buildspec-android.yml"
    report_build_status = true
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = "/aws/codebuild/${local.project_name}-build"
    }
  }

  project_visibility = "PUBLIC_READ"
}

resource "aws_iam_role" "codebuild_role" {
  name = "${local.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "codebuild.amazonaws.com"
      },
      Effect = "Allow",
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_iam_policy" "s3_artifacts" {
  name = "${local.project_name}-s3-artifacts-access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:GetObjectVersion",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation"
      ],
      Resource = [
        "arn:aws:s3:::${local.artifact_bucket}",
        "arn:aws:s3:::${local.artifact_bucket}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_s3" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.s3_artifacts.arn
}

resource "aws_iam_policy" "codebuild_logs" {
  name = "${local.project_name}-codebuild-logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_logs_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_logs.arn
}

resource "aws_cloudwatch_event_rule" "weekly_build" {
  name                = "${local.project_name}-weekly-build"
  schedule_expression = "cron(0 17 ? * MON *)" // each Monday at 17:00 UTC
  description         = "Trigger ahorro-ui android build project weekly"
}

resource "aws_iam_role" "codebuild_events_role" {
  name = "${local.project_name}-events-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "events.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_events_policy" {
  name = "${local.project_name}-events-policy"
  role = aws_iam_role.codebuild_events_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "codebuild:StartBuild"
      ],
      Resource = aws_codebuild_project.flutter_build.arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "weekly_build_target" {
  rule      = aws_cloudwatch_event_rule.weekly_build.name
  target_id = "CodeBuildProject"
  arn       = aws_codebuild_project.flutter_build.arn
  role_arn  = aws_iam_role.codebuild_events_role.arn
}
