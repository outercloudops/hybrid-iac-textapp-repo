terraform {
  required_providers {
    aws = {
      version = "6.45.0"
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket = var.artifacts_state_bucket 
/*variables.tf and tfvars used for terraform plan and apply reading of state bucket. keeps bucket name secure but for manual runs only. 
#TF_VAR env var in codebuild for artifact state bucket will be needed since .tfvars is not committed and not available at runtime for plan and apply. necessary for bootstrap remote state use in textapp bucket resources in main-infra. 
both codebuild TF_VAR env var and this artifact state bucket variable will be resolved by Terraform due to sharing the name*/
    key    = "bootstrap/terraform.tfstate"
    region = "us-east-1"
  }
}