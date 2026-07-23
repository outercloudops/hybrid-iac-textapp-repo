# Hybrid-IaC CI/CD Pipeline — American History Text App

Automated deployment pipeline for an HTML site and Python text app using a
hybrid Infrastructure-as-Code approach. Terraform provisions the core AWS
infrastructure. CodePipeline and CodeBuild handle automated delivery on every
push to main.

→ [Read Part 1](https://medium.com/@ivantrevino/devops-hybrid-iac-automated-solution-for-html-website-pyapp-w-terraform-aws-cloudfront-oac-a5083c8f00fd) · [Read Part 2](https://medium.com/@ivantrevino/devops-hybrid-iac-automated-solution-for-html-website-pyapp-w-terraform-aws-cloudfront-oac-6e77eb39cd27)

---

## What This Does

Pushes to main trigger CodePipeline automatically via GitHub webhook. CodeBuild
runs Terraform to provision or update infrastructure, then syncs the site source
to S3. CloudFront serves the content globally with OAC enforcing that S3 is
never accessed directly. Everything is encrypted at rest using a KMS
customer-managed key scoped to least-privilege.

---

## Architecture

- **Route53 + ACM** — custom domain with TLS at youramericanhistory.click
- **CloudFront + OAC** — CDN with origin access control, geo-restriction, custom TTL
- **S3** — private bucket with SSE-KMS, versioning, and lifecycle policies
- **KMS CMK** — customer-managed key with scoped key policy
- **Anthropic API Key** — API key for Anthropic API use in Founding Mirror textapp
- **CodePipeline + CodeBuild** — CI/CD triggered by GitHub webhook
- **SSM Parameter Store** — stores KMS key ARN for CodeBuild runtime use and Anthropic API key for app response use
- **IAM** — least-privilege service & execution roles for CodePipeline, CodeBuild, & Lambda
- **API Gateway + CORS** — Secondary origin, frontend AWS Proxy for Lambda handler app backend and routing Anthropic API requests towards it 
- **Lambda Function** — App backend comprising of python source code sharing app functionality with main.js in ah-text-app/js in S3  
---

## Repository Structure

    bootstrap/           One-time infrastructure: S3 state buckets, KMS CMK,
                         IAM roles, CodePipeline, CodeBuild, Lambda execution
                         role + policy + attachment
    main-infra/          Core resources: CloudFront, OAC, S3 app bucket,
                         API Gateway, Lambda Function, APIGW + Lambda Route,
                         Integration, & Stage
                         remote state data source, 
    ah-text-app/         HTML site source code and app lambda_handler.py 
    buildspec-infra.yml  CodeBuild HTML site build specification
    testing/             Pytest file to run checks against app logic living in 
                         handler via secondary dev pipeline
---

## Local Configuration Required

The following files are excluded via .gitignore and must be created
locally before running Terraform.

bootstrap/backend.hcl
    
    bucket = "your-artifacts-state-bucket-name"

main-infra/backend.hcl
    
    bucket = "your-state-bucket-name"

main-infra/terraform.tfvars
    
    bootstrap_state_bucket = "your-artifacts-state-bucket-name"

Bucket names follow the naming convention defined in bootstrap/locals.tf.

---

## How to Run

Bootstrap is a one-time manual run from your local environment:

    cd bootstrap
    terraform init -backend-config=backend.hcl
    terraform apply

For local main-infra inspection:

    cd main-infra
    terraform init -backend-config=backend.hcl
    terraform plan

Main-infra runs automatically via the pipeline on every push to main.

---

## Pipeline Environment Variables (CodeBuild)

- TEXTAPP_BUCKET              App S3 bucket name for aws s3 sync
- TEXTAPP_STATE_BUCKET        Main-infra backend bucket for terraform init
- TF_VAR_bootstrap_state_bucket   Artifacts state bucket for remote state data source

---

## Future Update To This Repo

- Add buildspec-test.yml for dev branch pipeline.
- Add buildspec-app.yml for main branch pipeline and app deployment.
- Update cmk.tf Cloudfront policy to prevent drift. 
- Add Lambda execution role, policy, and attachment configuration files in bootstrap.
- Add secondary origin for apigw to CloudFront distribution resource.
- Add Lambda Function, API Gateway, Route, Integration, & Stage resources in main-infra.
- Add CloudWatch Group resource for lambda function in main-infra.
