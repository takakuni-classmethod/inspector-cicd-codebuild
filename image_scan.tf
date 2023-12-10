#################################################
# IAM Role (Image Scan)
#################################################
resource "aws_iam_role" "image_scan" {
  name               = "${local.prefix}-image-scan"
  assume_role_policy = file("./policy_document/assume_codebuild.json")
}

resource "aws_iam_policy" "image_scan" {
  name   = "${local.prefix}-image-scan"
  policy = file("./policy_document/iam_codebuild_image_scan.json")
}

resource "aws_iam_role_policy_attachment" "image_scan" {
  role       = aws_iam_role.image_scan.name
  policy_arn = aws_iam_policy.image_scan.arn
}

#################################################
# CloudWatch Logs
#################################################
resource "aws_cloudwatch_log_group" "image_scan" {
  name              = "/aws/codebuild/${local.prefix}-image-scan"
  retention_in_days = 7
}

#################################################
# CodeBuild Project (Image Scan)
#################################################
resource "aws_codebuild_project" "image_scan" {
  name         = "${local.prefix}-image-scan"
  service_role = aws_iam_role.image_scan.arn

  source {
    type = "CODEPIPELINE"
    buildspec = "codebuild/image_scan.yaml"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    type         = "LINUX_CONTAINER"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"

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
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.image_scan.name
      status     = "ENABLED"
    }
  }
}