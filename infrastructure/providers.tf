provider "aws" {
  #region  = var.region
#  profile = var.profile
  alias = "use1"
}

# Create a remote backend for your terraform

terraform {
  backend "s3" {
    bucket = "meal-rocket-tfstate"
    use_lockfile = true  
    key = "LockID"
    encrypt = true
    region = "us-east-1"
    #profile = "default" 
  }
}