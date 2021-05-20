output "codepipeline_resources_bucket_arn" {
  description = ""
  value       = aws_s3_bucket.pipeline_resources_bucket.arn
}
