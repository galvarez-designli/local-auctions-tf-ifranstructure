provider "aws" {
  region = var.aws_region
}

# --- CONFIGURATION & LOCALS ---
locals {
  prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_caller_identity" "current" {}

# ---  S3 BUCKET ---
resource "aws_s3_bucket" "templates" {
  bucket        = "${local.prefix}-email-templates"
  force_destroy = var.environment == "dev"
  lifecycle {
    prevent_destroy = true
  }
  tags = local.common_tags
}

# --- SQS QUEUES ---
resource "aws_sqs_queue" "email_dlq" {
  name = "${local.prefix}-email-dlq"
  tags = local.common_tags
}

resource "aws_sqs_queue" "email_queue" {
  name                       = "${local.prefix}-email-queue"
  visibility_timeout_seconds = 60 # > Lambda timeout
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.email_dlq.arn
    maxReceiveCount     = 3
  })
  tags = local.common_tags
}

# --- SES IDENTITY ---
resource "aws_ses_email_identity" "sender" {
  email = var.sender_email
}

# --- IAM ROLES ---
resource "aws_iam_role" "lambda_role" {
  name = "${local.prefix}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_policy" "lambda_policy" {
  name = "${local.prefix}-lambda-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject"],
        Resource = "${aws_s3_bucket.templates.arn}/*"
      },
      {
        Effect   = "Allow",
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
        Resource = aws_sqs_queue.email_queue.arn
      },
      {
        Effect   = "Allow",
        Action   = ["ses:SendEmail", "ses:SendRawEmail"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "null_resource" "build_lambda" {
  triggers = {
    # Re-run if any file in src/ changes or package.json changes
    src_hash = sha1(join("", [for f in fileset("${path.module}/email-processor/src", "**") : filesha1("${path.module}/email-processor/src/${f}")]))
    pkg_hash = filesha1("${path.module}/email-processor/package.json")
  }

  provisioner "local-exec" {
    command = "cd ${path.module}/email-processor && npm install && npm run build"
  }
}

# --- LAMBDA FUNCTION ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/email-processor/dist"
  output_path = "${path.module}/lambda_function.zip"

  depends_on = [null_resource.build_lambda]
}

resource "aws_lambda_function" "email_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.prefix}-email-processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      TEMPLATE_BUCKET = aws_s3_bucket.templates.id
      SENDER_EMAIL    = var.sender_email
    }
  }
  tags = local.common_tags
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.email_queue.arn
  function_name    = aws_lambda_function.email_processor.arn
  batch_size       = 1
}
