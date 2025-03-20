locals {
  unique_bucket_name = "${var.s3_bucket_name}-${uuid()}" # ✅ Generates UUID once
}

# 🏗️ 1️⃣ Create S3 Bucket with a Unique Name
resource "aws_s3_bucket" "webapp_bucket" {
  bucket        = local.unique_bucket_name # ✅ Uses the single unique name
  force_destroy = true                     # ✅ Ensures Terraform can delete even if objects exist

  tags = {
    Name        = local.unique_bucket_name # ✅ Uses the same name for consistency
    Environment = "Production"
  }
}

# 🔒 2️⃣ Block Public Access to the Bucket
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.webapp_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 🔐 3️⃣ Enable Default Encryption for S3 Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.webapp_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # ✅ Enables AES-256 encryption by default
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.webapp_bucket.id

  rule {
    id     = "move-to-ia"
    status = "Enabled"

    filter {} # ✅ Applies rule to all objects in the bucket

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# 🎭 5️⃣ IAM Policy for EC2 Access to S3 (Optional)
resource "aws_iam_policy" "s3_access_policy" {
  name        = "WebAppS3Policy"
  description = "Allow EC2 instance to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.webapp_bucket.id}",
          "arn:aws:s3:::${aws_s3_bucket.webapp_bucket.id}/*"
        ]
      }
    ]
  })
}

# IAM Role for EC2 instance
resource "aws_iam_role" "webapp_role" {
  name = "WebAppS3Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach IAM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.webapp_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "webapp_profile" {
  name = "webapp_profile"
  role = aws_iam_role.webapp_role.name
}






