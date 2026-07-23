resource "aws_kms_key" "cmk_textapp" {
  description             = "CMK for Repo, Artifact, & App Encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 15
}

resource "aws_kms_key_policy" "cmk_textapp" {
  key_id = aws_kms_key.cmk_textapp.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "textapp_key_66"
    Statement = [
      {
        Sid    = "EnableKeyAdminPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },

      {
        Sid    = "AllowS3CMKUseForC9CodePipelineAndCodeBuild"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.codebuild_role.name}",    #can also aws_iam_role.codebuild_role.arn instead of the entire manual construction
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.codepipeline_role.name}", #aws_iam_role.codepipeline_role.arn
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/AWSCloud9SSMAccessRole"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "AllowCodeBuildToDecryptCMKParameter"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.codebuild_role.name}"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "AllowLambdaToDecryptAnthropicAPIKeyParameter"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.lambda_fm_exec.name}"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      },
      /*
      {
        Sid    = "AllowCodeBuildToUpdateCMKPolicy"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.codebuild_role.name}"
          ]
        }
        Action = [
          "kms:GetKeyPolicy",
          "kms:PutKeyPolicy"
        ],
        Resource = "*"
      },
      {
        Sid    = "CodeCommitUseOfCMK"
        Effect = "Allow"
        Principal = {
          Service = "codecommit.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "codecommit.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      },*/
      {
        Sid    = "AllowCloudFrontServicePrincipalSSE-KMS"
        Effect = "Allow",
        Principal = {
          Service = ["cloudfront.amazonaws.com"]
        }
        Action   = ["kms:Decrypt"], #due to GetObject & GET HTTP Method; Read
        Resource = "*"
        Condition = {
          StringLike = {
            "AWS:SourceArn" : "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/E2RWPA67GA7YPI" #explicit mention post deployment to prevent drift
          }                                                                                                                    #^ used to scope down to one resource; distribution
        }                                                                                                                      #StringEquals requires explicit distribution id. StringLike allows * processing for OAC handshake. 
      }                                                                                                                        #OAC handshake cannot process global IAM string wildcards for security verification during edge fetching. 
    ]
  })
}