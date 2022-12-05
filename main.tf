terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  dynamodb_point_in_time_recovery = {
    dev  = false
    prod = true
  }
  dynamodb_server_side_encryption = {
    dev  = false
    prod = true
  }
  aws_lambda_function_memory_size = {
    dev  = 128
    prod = 256
  }
  aws_lambda_function_timeout = {
    dev  = 3
    prod = 10
  }
}

resource "random_pet" "lambda_bucket" {
  prefix = "lambda-bucket-"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket.id
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

resource "aws_dynamodb_table" "songs_table" {
  name         = "songs-${terraform.workspace}"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "song_id"
    type = "S"
  }

  hash_key = "song_id"

  ttl {
    attribute_name = "expiryPeriod"
    enabled = true
  }

  point_in_time_recovery {
    enabled = local.dynamodb_point_in_time_recovery[terraform.workspace]
  }

  server_side_encryption {
    enabled = local.dynamodb_server_side_encryption[terraform.workspace]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb_lambda_policy" {
  name = "dynamodb_lambda_policy"
  role = aws_iam_role.iam_for_lambda.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : ["dynamodb:*"],
        "Resource" : "${aws_dynamodb_table.songs_table.arn}"
      }
    ]
  })
}

data "archive_file" "create_song_archive" {
  source_file = "lambdas/create_song.py"
  output_path = "lambdas/create_song.zip"
  type        = "zip"
}

resource "aws_s3_object" "lambda_create_song" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "create_song.zip"
  source = data.archive_file.create_song_archive.output_path

  etag = filemd5(data.archive_file.create_song_archive.output_path)
}

resource "aws_lambda_function" "create_song" {
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.songs_table.name
    }
  }
  function_name = "create-song-${terraform.workspace}"

  s3_key    = aws_s3_object.lambda_create_song.key
  s3_bucket = aws_s3_bucket.lambda_bucket.id

  runtime = "python3.9"
  handler = "create_song.lambda_handler"

  memory_size = local.aws_lambda_function_memory_size[terraform.workspace]
  timeout     = local.aws_lambda_function_timeout[terraform.workspace]
  role        = aws_iam_role.iam_for_lambda.arn
}

data "archive_file" "search_all_songs_archive" {
  source_file = "lambdas/search_all_songs.py"
  output_path = "lambdas/search_all_songs.zip"
  type        = "zip"
}

resource "aws_s3_object" "lambda_search_all_songs" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "search_all_songs.zip"
  source = data.archive_file.search_all_songs_archive.output_path

  etag = filemd5(data.archive_file.search_all_songs_archive.output_path)
}

resource "aws_lambda_function" "search_all_songs" {
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.songs_table.name
    }
  }
  function_name = "search-all-songs-${terraform.workspace}"

  s3_key    = aws_s3_object.lambda_search_all_songs.key
  s3_bucket = aws_s3_bucket.lambda_bucket.id

  runtime = "python3.9"
  handler = "search_all_songs.lambda_handler"

  memory_size = local.aws_lambda_function_memory_size[terraform.workspace]
  timeout     = local.aws_lambda_function_timeout[terraform.workspace]
  role        = aws_iam_role.iam_for_lambda.arn
}

data "archive_file" "delete_song_archive" {
  source_file = "lambdas/delete_song.py"
  output_path = "lambdas/delete_song.zip"
  type        = "zip"
}

resource "aws_s3_object" "lambda_delete_song" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "delete_song.zip"
  source = data.archive_file.delete_song_archive.output_path

  etag = filemd5(data.archive_file.delete_song_archive.output_path)
}

resource "aws_lambda_function" "delete_song" {
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.songs_table.name
    }
  }
  function_name = "delete-song-${terraform.workspace}"

  s3_key    = aws_s3_object.lambda_delete_song.key
  s3_bucket = aws_s3_bucket.lambda_bucket.id

  runtime = "python3.9"
  handler = "delete_song.lambda_handler"

  memory_size = local.aws_lambda_function_memory_size[terraform.workspace]
  timeout     = local.aws_lambda_function_timeout[terraform.workspace]
  role        = aws_iam_role.iam_for_lambda.arn
}

data "archive_file" "update_song_archive" {
  source_file = "lambdas/update_song.py"
  output_path = "lambdas/update_song.zip"
  type        = "zip"
}

resource "aws_s3_object" "lambda_update_song" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "update_song.zip"
  source = data.archive_file.update_song_archive.output_path

  etag = filemd5(data.archive_file.update_song_archive.output_path)
}

resource "aws_lambda_function" "update_song" {
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.songs_table.name
    }
  }
  function_name = "update-song-${terraform.workspace}"

  s3_key    = aws_s3_object.lambda_update_song.key
  s3_bucket = aws_s3_bucket.lambda_bucket.id

  runtime = "python3.9"
  handler = "update_song.lambda_handler"

  memory_size = local.aws_lambda_function_memory_size[terraform.workspace]
  timeout     = local.aws_lambda_function_timeout[terraform.workspace]
  role        = aws_iam_role.iam_for_lambda.arn
}

resource "aws_apigatewayv2_api" "songs_api" {
  name          = "songs-api-${terraform.workspace}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "songs_api" {
  api_id = aws_apigatewayv2_api.songs_api.id

  name        = "songs-api-${terraform.workspace}"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.songs_api.name}"

  retention_in_days = 30
}

resource "aws_apigatewayv2_integration" "create_song" {
  api_id = aws_apigatewayv2_api.songs_api.id

  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.create_song.invoke_arn
}

resource "aws_lambda_permission" "create_song" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_song.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.songs_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_route" "create_song" {
  api_id    = aws_apigatewayv2_api.songs_api.id
  route_key = "POST /songs"

  target = "integrations/${aws_apigatewayv2_integration.create_song.id}"
}

resource "aws_apigatewayv2_integration" "search_all_songs" {
  api_id = aws_apigatewayv2_api.songs_api.id

  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  description        = "Search all songs"
  integration_uri    = aws_lambda_function.search_all_songs.invoke_arn
}

resource "aws_lambda_permission" "search_all_songs" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search_all_songs.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.songs_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_route" "search_all_songs" {
  api_id    = aws_apigatewayv2_api.songs_api.id
  route_key = "GET /songs"

  target = "integrations/${aws_apigatewayv2_integration.search_all_songs.id}"
}

resource "aws_apigatewayv2_integration" "delete_song" {
  api_id = aws_apigatewayv2_api.songs_api.id

  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.delete_song.invoke_arn
}

resource "aws_lambda_permission" "delete_song" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_song.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.songs_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_route" "delete_song" {
  api_id    = aws_apigatewayv2_api.songs_api.id
  route_key = "DELETE /songs/{song_id}"

  target = "integrations/${aws_apigatewayv2_integration.delete_song.id}"
}

resource "aws_apigatewayv2_integration" "update_song" {
  api_id = aws_apigatewayv2_api.songs_api.id

  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  description        = "Update a song"
  integration_uri    = aws_lambda_function.update_song.invoke_arn
}

resource "aws_lambda_permission" "update_song" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_song.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.songs_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_route" "update_song" {
  api_id    = aws_apigatewayv2_api.songs_api.id
  route_key = "PUT /songs/{song_id}"

  target = "integrations/${aws_apigatewayv2_integration.update_song.id}"
}
