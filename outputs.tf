output "codepipeline_resources_bucket_arn" {
  description = "Codepipeline Resources Bucket ARN"
  value       = aws_s3_bucket.pipeline_resources_bucket.arn
}
