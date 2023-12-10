#################################################
# IAM Role (EventBridge)
#################################################
resource "aws_iam_role" "eventbridge" {
  name               = "${local.prefix}-eventbridge"
  assume_role_policy = file("./policy_document/assume_eventbridge.json")
}

resource "aws_iam_policy" "eventbridge" {
  name   = "${local.prefix}-eventbridge"
  policy = file("./policy_document/iam_eventbridge.json")
}

resource "aws_iam_role_policy_attachment" "eventbridge" {
  role       = aws_iam_role.eventbridge.name
  policy_arn = aws_iam_policy.eventbridge.arn
}

resource "aws_cloudwatch_event_rule" "codepipeline" {
  name = "${local.prefix}-codepipeline"

  event_pattern = templatefile("./event_pattern/codepipeline.json", {
    codecommit_arn = aws_codecommit_repository.main.arn
  })
}

resource "aws_cloudwatch_event_target" "codepipeline" {
  rule     = aws_cloudwatch_event_rule.codepipeline.name
  arn      = aws_codepipeline.main.arn
  role_arn = aws_iam_role.codepipeline.arn
}

#################################################
# IAM Role
#################################################
resource "aws_iam_role" "codepipeline" {
  name               = "${local.prefix}-pipeline"
  assume_role_policy = file("./policy_document/assume_codepipeline.json")
}

resource "aws_iam_policy" "codepipeline" {
  name   = "${local.prefix}-pipeline"
  policy = file("./policy_document/iam_codepipeline.json")
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipeline.arn
}

#################################################
# Artifact
#################################################
resource "aws_s3_bucket" "artifact" {
  bucket        = "${local.prefix}-artifact-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "artifact" {
  bucket = aws_s3_bucket.artifact.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "artifact" {
  bucket                  = aws_s3_bucket.artifact.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

#################################################
# CodePipeline
#################################################
resource "aws_codepipeline" "main" {
  name = "${local.prefix}-pipeline"

  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifact.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = 1
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName       = aws_codecommit_repository.main.repository_name
        BranchName           = "main"
        OutputArtifactFormat = "CODE_ZIP"
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      namespace        = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = 1
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.image_build.name
      }
    }
  }

  stage {
    name = "Scan"
    action {
      name             = "Scan"
      category         = "Build"
      namespace        = "Scan"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = 1
      input_artifacts  = ["source_output"]
      output_artifacts = ["scan_output"]
      

      configuration = {
        ProjectName = aws_codebuild_project.image_scan.name
        EnvironmentVariables = jsonencode([
          {
            name  = "IMAGE_URL"
            value = "#{Build.IMAGE_URL}"
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }

  stage {
    name = "Approval"
    action {
      name     = "Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = 1

      configuration = {
        CustomData         = "Container image scan result."
        ExternalEntityLink = "#{Scan.BUILD_URL}"
      }
    }
  }
}