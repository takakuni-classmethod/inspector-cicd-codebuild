#################################################
# IAM Role (Image Build)
#################################################
resource "aws_iam_role" "image_build" {
  name               = "${local.prefix}-image-build"
  assume_role_policy = file("./policy_document/assume_codebuild.json")
}

resource "aws_iam_policy" "image_build" {
  name   = "${local.prefix}-image-build"
  policy = file("./policy_document/iam_codebuild_image_build.json")
}

resource "aws_iam_role_policy_attachment" "image_build" {
  role       = aws_iam_role.image_build.name
  policy_arn = aws_iam_policy.image_build.arn
}

#################################################
# CloudWatch Logs (Image Build)
#################################################
resource "aws_cloudwatch_log_group" "image_build" {
  name              = "/aws/codebuild/${local.prefix}-image-build"
  retention_in_days = 7
}

#################################################
# CodeBuild Project (Image Build)
#################################################
resource "aws_codebuild_project" "image_build" {
  name         = "${local.prefix}-image-build"
  service_role = aws_iam_role.image_build.arn

  source {
    type = "CODEPIPELINE"
    buildspec = "codebuild/image_build.yaml"
  }

  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    type            = "LINUX_CONTAINER"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    privileged_mode = true

    environment_variable {
      type  = "PLAINTEXT"
      name  = "AWS_ACCOUNT_ID"
      value = local.account_id
    }

    environment_variable {
      type  = "PLAINTEXT"
      name  = "AWS_DEFAULT_REGION"
      value = local.region
    }

    environment_variable {
      type  = "PLAINTEXT"
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.main.name
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.image_build.name
      status     = "ENABLED"
    }
  }
}