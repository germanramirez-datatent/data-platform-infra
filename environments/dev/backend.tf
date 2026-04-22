terraform {
  backend "s3" {
    bucket         = "data-platform-tfstate-811430801421"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "data-platform-tfstate-lock"
    encrypt        = true
  }
}