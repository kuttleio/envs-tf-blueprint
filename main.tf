locals {
  region_name_bits    = split("-", var.clp_region)
  short_region_name   = "${local.region_name_bits[0]}${substr(local.region_name_bits[1], 0, 1)}${substr(local.region_name_bits[2], 0, 1)}"
  name_prefix         = "${local.short_region_name}-${var.clp_account}"
  standard_tags       = merge(var.global_tags, var.env_tags, tomap({
    EnvName           = "${local.name_prefix}-${var.clp_zenv}"
  }))
}

resource github_repository_file frontend {
  repository          = data.github_repository.frontend.name
  branch              = "master"
  file                = ".github/workflows/${local.name_prefix}-${var.clp_zenv}.yaml"
  commit_message      = "Add CICD: delivery from /master to ${var.clp_zenv}"
  commit_author       = "kuttle-bot"
  commit_email        = "kbot@ktl.ai"
  overwrite_on_create = true

  content = templatefile("${path.module}/cicd.tpl.yaml", {
    service_name  = "frontend"
    zenv          = var.clp_zenv
    region        = var.clp_region
    deploy_branch = "master"
    cluster_name  = module.ecs_fargate.cluster_name
  })
}

resource github_repository_file backend {
  repository          = data.github_repository.backend.name
  branch              = "master"
  file                = ".github/workflows/${local.name_prefix}-${var.clp_zenv}.yaml"
  commit_message      = "Add CICD: delivery from /master to ${var.clp_zenv}"
  commit_author       = "kuttle-bot"
  commit_email        = "kbot@ktl.ai"
  overwrite_on_create = true

  content = templatefile("${path.module}/cicd.tpl.yaml", {
    service_name  = "backend"
    zenv          = title(var.clp_zenv)
    region        = var.clp_region
    deploy_branch = "master"
    cluster_name  = module.ecs_fargate.cluster_name
  })
}

resource github_repository_file runner {
  repository          = data.github_repository.runner.name
  branch              = "master"
  file                = ".github/workflows/${local.name_prefix}-${var.clp_zenv}.yaml"
  commit_message      = "Add CICD: delivery from /master to ${var.clp_zenv}"
  commit_author       = "kuttle-bot"
  commit_email        = "kbot@ktl.ai"
  overwrite_on_create = true

  content = templatefile("${path.module}/cicd.tpl.yaml", {
    service_name  = "runner"
    zenv          = title(var.clp_zenv)
    region        = var.clp_region
    deploy_branch = "master"
    cluster_name  = module.ecs_fargate.cluster_name
  })
}

# ---------------------------------------------------
#    ECS Fargate cluster
# ---------------------------------------------------
module ecs_fargate {
  source          = "terraform-aws-modules/ecs/aws"
  version         = "4.1.3"
  cluster_name    = "${local.name_prefix}-${var.clp_zenv}"
  tags            = local.standard_tags
  
  cluster_settings = {
    name = "containerInsights"
    value = "enabled"
  }

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight  = 0
        base    = 0
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        base    = 10
        weight  = 100
      }
    }
  }
}

# ---------------------------------------------------
#    ECR Repo for automated deployment
# ---------------------------------------------------
resource aws_ecr_repository main {
  name                  = "${local.name_prefix}-${var.clp_zenv}"
  image_tag_mutability  = "MUTABLE"
  force_delete          = true

  encryption_configuration {
    encryption_type = "AES256"
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource aws_ecr_lifecycle_policy main {
  repository  = aws_ecr_repository.main.name
  policy      = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images older than 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}

# ---------------------------------------------------
#    Force New Deployment
# ---------------------------------------------------
module force_new_deployment {
  source          = "github.com/kuttleio/aws_ecs_fargate_force_new_deployment//?ref=1.0.9"
  ecs_cluster     = module.ecs_fargate.cluster_arn
  name_prefix     = "${local.name_prefix}-${var.clp_zenv}"
  standard_tags   = local.standard_tags
  account         = var.clp_account
}

# ---------------------------------------------------
#    Database
# ---------------------------------------------------
module postgre {
    source                 = "cloudposse/rds-cluster/aws"
    version                = "~> 1.4.0"
    name                   = "${local.name_prefix}-${var.clp_zenv}-PostgreSQL"
    engine                 = var.engine
    cluster_family         = var.cluster_family
    cluster_size           = var.cluster_size
    admin_user             = var.admin_user
    admin_password         = random_password.postgre.result
    db_name                = var.db_name
    db_port                = var.db_port
    instance_type          = var.instance_type
    autoscaling_enabled    = var.autoscaling_enabled
    vpc_id                 = data.terraform_remote_state.vpc.outputs.vpc_id
    security_groups        = [data.terraform_remote_state.sg.outputs.clp_bastion_sg]
    subnets                = data.terraform_remote_state.vpc.outputs.private_subnets
    tags                   = local.standard_tags
}

resource random_password postgre {
    length  = 24
    special = false
}

resource aws_ssm_parameter postgre_connection_string {
    name    = "/${local.name_prefix}/${var.clp_zenv}/postgre_connection_string"
    type    = "SecureString"
    value   = "postgres://${module.postgre.master_username}:${random_password.postgre.result}@${module.postgre.endpoint}/${module.postgre.database_name}"
    tags    = local.standard_tags
}

# ------------------------------------
#       ECS Task Role
# ------------------------------------
resource aws_iam_role main {
  name = "${local.name_prefix}-${var.clp_zenv}"
  tags = local.standard_tags

  managed_policy_arns = [
    aws_iam_policy.sqs.arn,
    aws_iam_policy.s3.arn,
    aws_iam_policy.ecs.arn,
    aws_iam_policy.rds.arn,
    aws_iam_policy.pricing.arn,  
  ]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource aws_iam_policy sqs {
  name = "${local.name_prefix}-${var.clp_zenv}-sqs"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "stmt1617103351726",
      "Effect": "Allow",
      "Action": [
        "sqs:*"
      ],
      "Resource": [
        "${aws_sqs_queue.main.arn}",
        "${aws_sqs_queue.reversed.arn}"
      ]
    }
  ]
}
POLICY
}

resource aws_iam_policy s3 {
  name = "${local.name_prefix}-${var.clp_zenv}-s3"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "stmt1617103351726",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${data.terraform_remote_state.s3_tf_artefacts.outputs.arn}",
        "${data.terraform_remote_state.s3_tf_artefacts.outputs.arn}/*"
      ]
    }
  ]
}
POLICY
}

resource aws_iam_policy ecs {
  name = "${local.name_prefix}-${var.clp_zenv}-ecs"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "stmt1617103351726",
      "Effect": "Allow",
      "Action": [
        "ecs:*"
      ],
      "Resource": "*",
      "Condition": {
        "ArnEquals": {
          "ecs:cluster": "${module.ecs_fargate.cluster_arn}"
        }
      }
    }
  ]
}
POLICY
}

resource aws_iam_policy rds {
  name        = "${local.name_prefix}-${var.clp_zenv}-rds"
  description = "Policy for RDS permissions"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1617103351727",
      "Effect": "Allow",
      "Action": "rds:DescribeDBInstances",
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "pricing" {
  name        = "${local.name_prefix}-${var.clp_zenv}-pricing"
  description = "Policy for IAM role"
  policy      = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1617103351727",
      "Effect": "Allow",
      "Action": [
        "pricing:DescribeServices",
        "pricing:GetProducts"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

# ---------------------------------------------------
#   Security Group for Public LBs
# ---------------------------------------------------
resource aws_security_group main {
    name        = "${local.name_prefix}-${var.clp_zenv} LB SG"
    description = "LB Access SG"
    vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
    tags        = merge(local.standard_tags, tomap({ Name = "${local.name_prefix}-${var.clp_zenv} LB security group" }))

    egress {
        from_port     = 0
        to_port       = 0
        protocol      = "-1"
        cidr_blocks   = ["0.0.0.0/0"]
    }

    ingress {
        from_port     = 80
        to_port       = 80
        protocol      = "tcp"
        cidr_blocks   = var.allowed_cidr_blocks
    }

    ingress {
        from_port     = 443
        to_port       = 443
        protocol      = "tcp"
        cidr_blocks   = var.allowed_cidr_blocks
    }
}

# ---------------------------------------------------
#   Public LB - Frontend
# ---------------------------------------------------
resource aws_lb frontend {
    name               = "${local.name_prefix}-${var.clp_zenv}-Frontend-LB"
    load_balancer_type = "application"
    security_groups    = [aws_security_group.main.id]
    subnets            = data.terraform_remote_state.vpc.outputs.public_subnets

    access_logs {
        bucket  = aws_s3_bucket.logs.bucket
        prefix  = "frontend_lb"
        enabled = true
    }

    tags = merge(local.standard_tags, tomap({ Name = "${local.name_prefix}-${var.clp_zenv}-Frontend-LB" }))
}

resource aws_route53_record frontend {
    zone_id = data.aws_route53_zone.main.zone_id
    name    = "${var.clp_zenv}."
    type    = "CNAME"
    ttl     = 300
    records = [aws_lb.frontend.dns_name]
}

# ---------------------------------------------------
#   Public LB - Backend
# ---------------------------------------------------
resource aws_lb backend {
    name               = "${local.name_prefix}-${var.clp_zenv}-Backend-LB"
    load_balancer_type = "application"
    security_groups    = [aws_security_group.main.id]
    subnets            = data.terraform_remote_state.vpc.outputs.public_subnets

    access_logs {
        bucket  = aws_s3_bucket.logs.bucket
        prefix  = "backend_lb"
        enabled = true
    }

    tags = merge(local.standard_tags, tomap({ Name = "${local.name_prefix}-${var.clp_zenv}-Backend-LB" }))
}

resource aws_route53_record backend {
    zone_id = data.aws_route53_zone.main.zone_id
    name    = "${var.clp_zenv}-backend."
    type    = "CNAME"
    ttl     = 300
    records = [aws_lb.backend.dns_name]
}

# ---------------------------------------------------
#   S3 bucket + policy
# ---------------------------------------------------
resource aws_s3_bucket logs {
    bucket          = "${local.name_prefix}-${var.clp_zenv}-lb-logs"
    force_destroy   = true
    acl             = "private"
    tags            = local.standard_tags

    versioning {
        enabled = true
    }

    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
            }
        }
    }

    lifecycle_rule {
        id      = "log"
        enabled = true
        expiration {
            days = 30
        }
        noncurrent_version_expiration {
            days = 30
        }
    }     
}

resource aws_s3_bucket_public_access_block logs {
    bucket                    = aws_s3_bucket.logs.id
    block_public_acls         = true
    block_public_policy       = true
    ignore_public_acls        = true
    restrict_public_buckets   = true
}

resource aws_s3_bucket_policy logs {
    bucket = aws_s3_bucket.logs.id
    policy = <<POLICY
{
    "Id": "LogBucketPolicy",
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": [
            "s3:PutObject"
            ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.logs.id}/*",
        "Principal": {
            "AWS": [
                "${data.aws_elb_service_account.main.arn}"
                ]
            }
        }
    ]
}
POLICY
}

# ---------------------------------------------------
#    LogDNA
# ---------------------------------------------------
resource logdna_view main {
    name        = "${var.clp_zenv}-${local.short_region_name} - logs"
    query       = "-health"
    categories  = ["DEV"]
    tags        = ["${local.name_prefix}-${var.clp_zenv}"]
}

resource logdna_view errors {
    levels      = ["error"]
    name        = "${var.clp_zenv}-${local.short_region_name} - errors"
    query       = "-health"
    categories  = ["DEV"]
    tags        = ["${local.name_prefix}-${var.clp_zenv}"]

    # slack_channel {
    #     immediate       = "true"
    #     operator        = "presence"
    #     terminal        = "false"
    #     triggerinterval = "30"
    #     triggerlimit    = 1
    #     url             = var.logdna_slack_non_prod_alerts
    # }
}

# ---------------------------------------------------
#    LogDNA pushing logs from CloudWatch
# ---------------------------------------------------
data aws_ssm_parameter logdna_ingestion_key {
    name            = "/${local.name_prefix}/logdna_ingestion_key"
    with_decryption = true
}

module lambda {
    source  = "terraform-aws-modules/lambda/aws"
    version = "~> 4.0"

    function_name                       = "${local.name_prefix}-${var.clp_zenv}-logdna-lambda"
    description                         = "Push CloudWatch logs to LogDNA for ${var.clp_zenv}-${local.short_region_name}"
    handler                             = "index.handler"
    runtime                             = "nodejs18.x"
    timeout                             = 10
    memory_size                         = 256
    maximum_retry_attempts              = 0
    create_package                      = false
    local_existing_package              = "${path.module}/lambda.zip"
    tags                                = local.standard_tags
    cloudwatch_logs_retention_in_days   = 1

    environment_variables = {
        LOGDNA_KEY          = data.aws_ssm_parameter.logdna_ingestion_key.value
        LOGDNA_TAGS         = "${local.name_prefix}-${var.clp_zenv}"
        LOG_RAW_EVENT       = "yes"
    }
}

resource aws_lambda_permission allow_cloudwatch {
    action        = "lambda:InvokeFunction"
    function_name = module.lambda.lambda_function_name
    principal     = "logs.${data.aws_region.current.name}.amazonaws.com"
}

# ---------------------------------------------------
#    Service Discovery Namespace
# ---------------------------------------------------
resource aws_service_discovery_private_dns_namespace main {
  name        = "${local.name_prefix}-${var.clp_zenv}-ns"
  description = "${local.name_prefix}-${var.clp_zenv} Private Namespace"
  vpc         = data.terraform_remote_state.vpc.outputs.vpc_id
}

# ---------------------------------------------------
#    Services
# ---------------------------------------------------
module frontend {
  source                  = "github.com/kuttleio/aws_ecs_fargate_app"
  public                  = true
  service_name            = "frontend"
  service_image           = "${aws_ecr_repository.main.repository_url}:frontend"
  name_prefix             = local.name_prefix
  standard_tags           = local.standard_tags
  cluster_name            = module.ecs_fargate.cluster_name
  zenv                    = var.clp_zenv
  desired_count           = 1
  container_cpu           = 1024
  container_memory        = 2048
  vpc_id                  = data.terraform_remote_state.vpc.outputs.vpc_id
  security_groups         = [data.terraform_remote_state.sg.outputs.clp_backend_sg, data.terraform_remote_state.sg.outputs.clp_bastion_sg, aws_security_group.main.id]
  subnets                 = data.terraform_remote_state.vpc.outputs.private_subnets
  ecr_account_id          = var.account_id
  ecr_region              = var.ecr_region
  aws_lb_arn              = aws_lb.frontend.arn
  aws_lb_certificate_arn  = data.aws_acm_certificate.main.arn
  logs_destination_arn    = module.lambda.lambda_function_arn
  domain_name             = var.domain_name
  task_role_arn           = aws_iam_role.main.arn
  secrets                 = setunion(data.terraform_remote_state.regional_secrets.outputs.regional_secrets)
  environment             = setunion(data.terraform_remote_state.regional_secrets.outputs.regional_env_vars, local.added_env)
}

module backend {
  source                  = "github.com/kuttleio/aws_ecs_fargate_app"
  public                  = true
  service_name            = "backend"
  service_image           = "${aws_ecr_repository.main.repository_url}:backend"
  name_prefix             = local.name_prefix
  standard_tags           = local.standard_tags
  cluster_name            = module.ecs_fargate.cluster_name
  zenv                    = var.clp_zenv
  desired_count           = 1
  container_cpu           = 1024
  container_memory        = 2048
  vpc_id                  = data.terraform_remote_state.vpc.outputs.vpc_id
  security_groups         = [data.terraform_remote_state.sg.outputs.clp_backend_sg, data.terraform_remote_state.sg.outputs.clp_bastion_sg, aws_security_group.main.id]
  subnets                 = data.terraform_remote_state.vpc.outputs.private_subnets
  ecr_account_id          = var.account_id
  ecr_region              = var.ecr_region
  aws_lb_arn              = aws_lb.backend.arn
  aws_lb_certificate_arn  = data.aws_acm_certificate.main.arn
  logs_destination_arn    = module.lambda.lambda_function_arn
  domain_name             = var.domain_name
  task_role_arn           = aws_iam_role.main.arn
  secrets                 = setunion(data.terraform_remote_state.regional_secrets.outputs.regional_secrets)
  environment             = setunion(data.terraform_remote_state.regional_secrets.outputs.regional_env_vars, local.added_env, [
    {
      name  = "UPDATE_STATUSES_CRON"
      value = "*/10 * * * *"
    },
    {
      name  = "IS_WORKER"
      value = "1"
    },
  ])
}

module runner {
  source                  = "github.com/kuttleio/aws_ecs_fargate_app"
  public                  = false
  service_name            = "runner"
  service_image           = "${aws_ecr_repository.main.repository_url}:runner"
  name_prefix             = local.name_prefix
  standard_tags           = local.standard_tags
  cluster_name            = module.ecs_fargate.cluster_name
  zenv                    = var.clp_zenv
  container_cpu           = 1024
  container_memory        = 2048
  vpc_id                  = data.terraform_remote_state.vpc.outputs.vpc_id
  security_groups         = [data.terraform_remote_state.sg.outputs.clp_backend_sg, data.terraform_remote_state.sg.outputs.clp_bastion_sg, aws_security_group.main.id]
  subnets                 = data.terraform_remote_state.vpc.outputs.private_subnets
  ecr_account_id          = var.account_id
  ecr_region              = var.ecr_region
  logs_destination_arn    = module.lambda.lambda_function_arn
  service_discovery_id    = aws_service_discovery_private_dns_namespace.main.id
  domain_name             = var.domain_name
  task_role_arn           = aws_iam_role.main.arn
  secrets                 = setunion(data.terraform_remote_state.regional_secrets.outputs.regional_secrets)
  environment             = setunion(data.terraform_remote_state.regional_secrets.outputs.regional_env_vars, local.added_env)
}

# ---------------------------------------------------
#    SQS
# ---------------------------------------------------
resource aws_sqs_queue main {
  name                        = "${local.name_prefix}-${var.clp_zenv}"
  visibility_timeout_seconds  = 900
  tags                        = local.standard_tags
  sqs_managed_sse_enabled     = true
}

resource aws_sqs_queue reversed {
  name                        = "${local.name_prefix}-${var.clp_zenv}-reversed"
  visibility_timeout_seconds  = 900
  tags                        = local.standard_tags
  sqs_managed_sse_enabled     = true
}


