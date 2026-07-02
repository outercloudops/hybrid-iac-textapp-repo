output "kms_key_arn" {
  description = "CMK ARN"
  value       = aws_kms_key.cmk_textapp.arn
}
output "kms_key_id" {
  description = "CMK id"
  value       = aws_kms_key.cmk_textapp.id
}