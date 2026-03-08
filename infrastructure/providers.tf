provider "aws" {
  #region  = var.region
#  profile = var.profile
  alias = "use1"
}

# Create a remote backend for your terraform

terraform {
  backend "s3" {
    bucket = "meal-rocket-tfstate"
    dynamodb_table = "meal-rocket-tfstate"
    key = "LockID"
#    region = var.region
#    profile = var.profile  
  }
}