provider "aws" {
  #region  = var.region
#  profile = var.profile
  alias = "use1"
}

# Create a remote backend for your terraform

terraform {
  backend "s3" {
    bucket = "meal-rocket-tfstate"
    key = "LockID"
    encrypt = true
    region = "us-east-1"
    dynamodb_table = "meal-rocket-tfstate"
    #profile = "default" 
  }
}