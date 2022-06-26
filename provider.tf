provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

module "s3_lambda" {
  source = "./mod/"
}