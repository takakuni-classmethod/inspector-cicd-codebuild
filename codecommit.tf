#################################################
# CodeCommit Repository
#################################################
resource "aws_codecommit_repository" "main" {
  repository_name = "${local.prefix}-repo"
}