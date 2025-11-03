# unique bucket name
resource "aws_s3_bucket" "app_bucket" {
  bucket_prefix = "${var.bucket_name_prefix}-${var.env}-"
  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.app_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}