locals {
  codebuild_project_name = "textapp-deployment-build-stage"
  artifact_state_key     = "bootstrap/terraform.tfstate"
  artifact_lock_file     = "${local.artifact_state_key}.tflock"
  textapp_bucket         = format("textapp-bucket-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  textapp_state_key      = "main-infra/terraform.tfstate"
  textapp_lock_file      = "${local.textapp_state_key}.tflock"
}