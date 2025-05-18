# ========== S3 BUCKET (ALT - Avoid Duplicate Name) ==========
resource "aws_s3_bucket" "tf_state_main" {
  bucket = "terraform-state-${var.bucket_name}"
  force_destroy = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "Terraform State Bucket"
  }
}

# ========== DYNAMODB TABLE FOR LOCKING ==========
resource "aws_dynamodb_table" "tf_lock" {
  name         = "terraform-lock-${var.bucket_name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform Lock Table"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ========== IAM POLICY TO ALLOW S3 ACCESS ==========
resource "aws_iam_policy" "s3_access_policy" {
  name = "TerraformStateS3Policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:CreateBucket",
          "s3:PutBucketVersioning",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation",
          "s3:PutBucketEncryption",
          "s3:PutBucketPolicy",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.tf_state_main.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.tf_state_main.bucket}/*"
        ]
      }
    ]
  })
}

# ========== IAM ROLE ==========
resource "aws_iam_role" "tf_role" {
  name = "TerraformExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# ========== ATTACH POLICIES ==========
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.tf_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

