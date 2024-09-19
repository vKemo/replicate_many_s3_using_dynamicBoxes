provider "aws" {
  region     = "eu-west-1"
  access_key  = "aws_access_key"
  secret_key  = "aws_secret_access_key"
}

provider "aws" {
  alias      = "central"
  region     = "eu-central-1"
  access_key  = "aws_access_key"
  secret_key  = "aws_secret_access_key"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "replication" {
  name               = "kareem-iam-role5"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "replication" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.source.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]
    resources = ["${aws_s3_bucket.source.arn}/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]
    resources = [ #creating a list where each item is a string that represents all objects in each destination bucket thee number of items in this list matches the number of destination buckets you have.
      for i in range(length(var.Destination_Bucket)) : #it will loop through 0, 1 because we have 2 des.
      "${aws_s3_bucket.destination[i].arn}/*"  
    ]
  }
}

resource "aws_iam_policy" "replication" {
  name   = "kareem-iam-policy5"
  policy = data.aws_iam_policy_document.replication.json
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

resource "aws_s3_bucket" "source" {
  provider = aws.central
  bucket   = var.Source_Bucket_Name
}

resource "aws_s3_bucket_versioning" "source" {
  provider = aws.central
  bucket   = aws_s3_bucket.source.id
  versioning_configuration {
    status = var.Versioning
  }
}

resource "aws_s3_bucket" "destination" {
  count  = length(var.Destination_Bucket)
  bucket = var.Destination_Bucket[count.index]
}

resource "aws_s3_bucket_versioning" "destination" {
  count  = length(var.Destination_Bucket)
  bucket = aws_s3_bucket.destination[count.index].id
  versioning_configuration {
    status = var.Versioning
  }
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.central
  depends_on = [
    aws_s3_bucket_versioning.source,
    aws_s3_bucket_versioning.destination,
  ]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.source.id

  dynamic "rule" { #this block dynamically creates replication rules based on the var.Filter_For_First_Destination variable.
    for_each = var.Destination_Filter #Iterates over var.Filter_For_First_Destination using for_each
      
    content {
      id     = "replication${rule.key}" #assigns a unique identifier to the replication rule,created by appending the current iteration’s key
      status = "Enabled"
      priority = rule.key + 1 #make it increase by 1 because it starts with 0

      filter {
        prefix = rule.value #applies the replication rule only to objects with a specific prefix in the source bucket. The prefix is taken from rule.value.
      }

      destination {
        bucket        = aws_s3_bucket.destination[rule.key].arn #defines the destination bucket for the replication
        storage_class = "STANDARD"
      }

      delete_marker_replication {
        status = "Disabled"
      }
    }
  }
}
