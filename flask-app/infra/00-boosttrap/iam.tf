# ========== S3 BUCKET FOR TERRAFORM STATE ==========
resource "aws_s3_bucket" "tf_state" {
  bucket = var.bucket_name

  tags = {
    Name = "Terraform State Bucket"
  }
}

# ========== ENABLE VERSIONING ==========
resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ========== ENABLE ENCRYPTION ==========
resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ========== DYNAMODB TABLE FOR LOCKING ==========
resource "aws_dynamodb_table" "tf_lock" {
  name         = "${var.bucket_name}-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform Lock Table"
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
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      }
    ]
  })
}

# ========== IAM POLICY TO ALLOW DYNAMODB LOCKING ==========
resource "aws_iam_policy" "dynamodb_lock_policy" {
  name = "TerraformDynamoDBLockPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ],
        Resource = "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${aws_dynamodb_table.tf_lock.name}"
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

# ========== ATTACH POLICIES TO ROLE ==========
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.tf_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_dynamodb_policy" {
  role       = aws_iam_role.tf_role.name
  policy_arn = aws_iam_policy.dynamodb_lock_policy.arn
}

# ========== GET ACCOUNT ID ==========
data "aws_caller_identity" "current" {}
