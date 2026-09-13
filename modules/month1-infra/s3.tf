resource "aws_s3_bucket" "milestone" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "milestone" {
  bucket = aws_s3_bucket.milestone.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "milestone" {
  bucket = aws_s3_bucket.milestone.id
  rule {
    id     = "ExpireOldLogs"
    status = "Enabled"
    filter { prefix = "logs/" }
    expiration { days = 30 }
  }
}

resource "aws_s3_bucket_website_configuration" "milestone" {
  bucket = aws_s3_bucket.milestone.id
  index_document { suffix = "index.html" }
}

resource "aws_s3_bucket_public_access_block" "milestone" {
  bucket                  = aws_s3_bucket.milestone.id
  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "milestone" {
  bucket = aws_s3_bucket.milestone.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadForStaticSite"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.milestone.arn}/*"
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.milestone]
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.milestone.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  etag         = filemd5("${path.module}/index.html")
  content_type = "text/html"
}
