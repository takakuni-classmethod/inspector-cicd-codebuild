#################################################
# Container Repository
#################################################
resource "aws_ecr_repository" "main" {
  name = "${local.prefix}-repo"
  force_delete = true
}