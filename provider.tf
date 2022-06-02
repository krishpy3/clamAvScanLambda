provider "aws" {
  region  = "us-east-1"
  profile = "default"
}


data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}
