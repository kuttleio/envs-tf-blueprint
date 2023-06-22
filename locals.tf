# ---------------------------------------------------
#    Additional Env Variables
# ---------------------------------------------------
locals {
  added_env = [
    {
      name  = "REACT_APP_BACKEND_ENDPOINT"
      value = "https://${aws_route53_record.backend.fqdn}/api/v1"
    },
    {
      name  = "BACKEND_PATH"
      value = "https://${aws_route53_record.backend.fqdn}"
    },
    {
      name  = "FRONTEND_PATH"
      value = "https://${aws_route53_record.frontend.fqdn}"
    },
    {
      name  = "QUEUE_URL"
      value = aws_sqs_queue.main.url
    },
    {
      name  = "QUEUE_URL_REVERSED"
      value = aws_sqs_queue.reversed.url
    },
    {
      name  = "S3_TERRAFORM_ARTEFACTS"
      value = data.terraform_remote_state.s3_tf_artefacts.outputs.id
    },
  ]
}

