provider "aws" {
  region = "eu-west-1"
}

terraform {
  backend "s3" {
    key = "example-terraform/terraform.tfstate"
  }
}
