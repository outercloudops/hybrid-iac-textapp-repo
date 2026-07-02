terraform {
  backend "s3" {
    # bucket removed and passed to backend.hcl to keep secret
    key          = "main-infra/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}