# ---------------------------------------------------
#    Cluster - Outputs
# ---------------------------------------------------
output cluster_id {
  description = "ECS Fargate Cluster ID"
  value       = module.ecs_fargate.cluster_id
}

output cluster_arn {
  description = "ECS Fargate Cluster ARN"
  value       = module.ecs_fargate.cluster_arn
}

output cluster_name {
  description = "ECS Fargate Cluster Name"
  value       = module.ecs_fargate.cluster_name
}

output ecr_repo_url {
  value = aws_ecr_repository.main.repository_url
}


# ---------------------------------------------------
#   DB Postgre - Outputs
# ---------------------------------------------------
output db_name {
    value       = module.postgre.database_name
    description = "DB name"
}

output db_master_username {
    value       = module.postgre.master_username
    description = "DB master username"
    sensitive   = true
}

output db_cluster_identifier {
    value       = module.postgre.cluster_identifier
    description = "Cluster Identifier"
}

output db_arn {
    value       = module.postgre.arn
    description = "RDS Cluster ARN"
}

output db_endpoint {
    value       = module.postgre.endpoint
    description = "RDS DNS endpoint"
}

output db_reader_endpoint {
    value       = module.postgre.reader_endpoint
    description = "RDS ReadOnly endpoint"
}

output db_master_host {
    value       = module.postgre.master_host
    description = "DB Master hostname"
}

output db_replicas_host {
    value       = module.postgre.replicas_host
    description = "Replicas hostname"
}

# ---------------------------------------------------
#   Public LBs - Outputs
# ---------------------------------------------------
output frontend_public_lb_arn {
    description = "Admin Public LB ARN"
    value       = aws_lb.frontend.arn
}

output frontend_url {
    value = "https://${aws_route53_record.frontend.fqdn}"
}

output frontend_fqdn {
    value = aws_route53_record.frontend.fqdn
}

output backend_public_lb_arn {
    description = "Admin Public LB ARN"
    value       = aws_lb.backend.arn
}

output backend_url {
    value = "https://${aws_route53_record.backend.fqdn}"
}

output backend_fqdn {
    value = aws_route53_record.backend.fqdn
}

# ---------------------------------------------------
#   Mezmo (LogDNA) - Outputs
# ---------------------------------------------------
output logdna_view_url {
    value = "https://app.mezmo.com/${var.mezmo_account_id}/logs/view/${logdna_view.main.id}"
}

output logdna_view_id {
    value = logdna_view.main.id
}
