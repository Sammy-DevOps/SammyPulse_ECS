terraform {
  backend "s3" {
    bucket       = "sammypulse-terraform-state"
    key          = "sammypulse/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-west-2"
}
