data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# The role itself
resource "aws_iam_role" "lambda_fm_exec" {
  name               = "founding-mirror-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = { project = "founding-mirror-textapp" }
}

# SSM + KMS permissions policy document
data "aws_iam_policy_document" "lambda_fm_ssm_kms" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/founding_mirror/anthropic_api_key"]
  } #manual arn construction if parameter made in console. regional. no arn reference because not a terraform provisioned resource. 
  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [aws_kms_key.cmk_textapp.arn]
  }
}

# Standalone managed policy
resource "aws_iam_policy" "lambda_fm_ssm_kms" {
  name        = "founding-mirror-lambda-ssm-kms"
  description = "Lambda SSM read and KMS decrypt for Anthropic API key"
  policy      = data.aws_iam_policy_document.lambda_fm_ssm_kms.json
}

# Attach SSM/KMS policy to role
resource "aws_iam_role_policy_attachment" "lambda_fm_ssm_kms" {
  role       = aws_iam_role.lambda_fm_exec.name
  policy_arn = aws_iam_policy.lambda_fm_ssm_kms.arn
}

# Attach AWS managed basic execution policy (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_fm_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
} #^ because managed policies only have aws. no account id.