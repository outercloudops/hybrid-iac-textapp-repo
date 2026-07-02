data "aws_iam_policy_document" "codepipeline_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "codepipeline-textapp-servicerole"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role.json
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    sid    = "ArtifactFullBucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetBucketVersioning",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.pipeline_artifacts.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.pipeline_artifacts.bucket}/*"
    ]
  }
  /*statement {
    sid    = "CICDPipelineExecutionPermissions"
    effect = "Allow"
    actions = [
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:UploadArchive",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:CancelUploadArchive"
    ]
    resources = ["arn:aws:codecommit:us-east-1:${data.aws_caller_identity.current.account_id}:textapp-repo"]
  }*/
  statement {
    sid    = "CodeConnectionsUse"
    effect = "Allow"
    actions = [
      "codeconnections:UseConnection",
      "codestar-connection:UseConnection"
    ]
    resources = [
      "arn:aws:codeconnections:us-east-1:${data.aws_caller_identity.current.account_id}:connection/*",
      "arn:aws:codestar-connection:us-east-1:${data.aws_caller_identity.current.account_id}:connection/*"
    ]
  }

  statement {
    sid    = "InvokeCodeBuild"
    effect = "Allow"
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds"
    ]
    resources = ["arn:aws:codebuild:us-east-1:${data.aws_caller_identity.current.account_id}:project/${local.codebuild_project_name}"] #can use locals for project name too
  }
  statement {
    sid    = "KMSArtifactEncryption"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.cmk_textapp.arn]
  }
}

resource "aws_iam_policy" "codepipeline_policy" {
  name        = "codepipeline-textapp-policy"
  description = "codepipeline policy for textapp"
  policy      = data.aws_iam_policy_document.codepipeline_policy.json
}

resource "aws_iam_role_policy_attachment" "codepipeline_attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}