data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

variable "system" {
  type    = string
  default = "inspector"
}

variable "env" {
  type    = string
  default = "scan"
}

locals {
  prefix     = "${var.system}-${var.env}"
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
}
