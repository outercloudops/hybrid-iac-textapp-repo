resource "aws_lambda_function" "founding_mirror" {
  filename      = "./ah-text-app/lambda_handler.zip" # no data archive source since zip will be handled in buildspec-app
  function_name = "founding-mirror"
  role          = aws_iam_role.lambda_exec.arn
  # Format: filename_without_extension.function_name
  # lambda_handler.py contains a function called lambda_handler.
  handler          = "lambda_handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("./ah-text-app/lambda_handler.zip")
  timeout          = 30
  memory_size      = 128 # 128 is the minimum. MB.
  environment {
    variables = {
      SSM_PARAMETER_NAME = "/founding_mirror/anthropic_api_key" #lambda will retreive this variable in logic
    }
  }

  tags = {
    Project = "founding-mirror"
  }
}

resource "aws_apigatewayv2_api" "founding_mirror" {
  name            = "founding-mirror-api"
  protocol_type   = "HTTP"
  version         = "1"
  ip_address_type = "dualstack"
  cors_configuration {                                                                             # controls which origins can call this API from a browser. Without this, the browser blocks the fetch() call entirely.
    allow_origins = ["https://youramericanhistory.click", "https://www.youramericanhistory.click"] #www because of alias
    allow_methods = ["POST"]                                                                       # Only POST is needed — that is the only method the app uses.
    allow_headers = ["Content-Type"]                                                               # Content-Type must be allowed so the JSON body passes through.
  }

  tags = {
    Project     = "founding-mirror"
    Environment = "production"
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.founding_mirror.id
  integration_type       = "AWS_PROXY"                                    #Lambda proxy integration. AWS Service, not server. Full request forwarded.
  integration_uri        = aws_lambda_function.founding_mirror.invoke_arn #invoke_arn includes the region and is required for API GW.
  connection_type        = "INTERNET"                                     #if not stated, defaults to internet
  description            = "founding mirror integretation for API GW & Lambda"
  payload_format_version = "2.0" # "2.0" is the current format for HTTP APIs. "1.0" is the legacy format for REST APIs.
}

resource "aws_apigatewayv2_route" "ask" {
  api_id    = aws_apigatewayv2_api.founding_mirror.id
  route_key = "POST /api/ask" #not file in path or pathtodirectory. would be in main.js code in js dir. matches the path CloudFront forwards to API GW.
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.founding_mirror.id
  name        = "$default" # "$default" means requests go to the root URL, not /stagename/
  auto_deploy = true       #for api config changes. w/o, manual deployment needed

  tags = {
    Project = "founding-mirror"
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.founding_mirror.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.founding_mirror.execution_arn}/*/*" #/stage/http-method
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/founding-mirror"
  retention_in_days = 30
  tags = {
    Project = "founding-mirror"
  }
}