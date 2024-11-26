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
  name          = "${local.prefix}-pipeline"
  pipeline_type = "V2"

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
      namespace        = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = 1
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = var.connection_arn
        FullRepositoryId = "takakuni-classmethod/inspector-cicd-codebuild" # 任意の値を入力
        BranchName       = "v2"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name            = "Build"
      category        = "Build"
      namespace       = "Build"
      owner           = "AWS"
      provider        = "ECRBuildAndPublish"
      version         = 1
      input_artifacts = ["source_output"]

      configuration = {
        ECRRepositoryName = aws_ecr_repository.main.name
        DockerFilePath    = "./docker"
        ImageTags         = "#{Source.CommitId}"
      }
    }
  }

  stage {
    name = "Scan"
    action {
      name             = "Scan"
      category         = "Invoke"
      namespace        = "Scan"
      owner            = "AWS"
      provider         = "InspectorScan"
      version          = 1
      input_artifacts  = []
      output_artifacts = ["scan_output"]

      configuration = {
        InspectorRunMode  = "ECRImageScan"
        ECRRepositoryName = aws_ecr_repository.main.name
        ImageTag          = "#{Source.CommitId}"
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
        CustomData = "Container image scan result."
        # ExternalEntityLink = "#{Scan.BUILD_URL}"
      }
    }
  }
}
