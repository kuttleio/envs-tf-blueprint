data aws_region current {}
data aws_elb_service_account main {}
data github_repository frontend {
  full_name = "kuttleio/frontend"
}

data github_repository backend {
  full_name = "kuttleio/backend"
}

data github_repository runner {
  full_name = "kuttleio/runner"
}

data aws_ssm_parameter logdna_service_key {
    name            = "/${local.name_prefix}/logdna_service_key"
    with_decryption = true
}

data aws_ssm_parameter github_token {
    name            = "/${local.name_prefix}/github_token"
    with_decryption = true
}

data aws_route53_zone main {
    name = var.domain_name
}

data aws_acm_certificate main {
    domain      = "*.${var.domain_name}"
    statuses    = ["ISSUED"]
    most_recent = true
}

data terraform_remote_state iam {
    backend = "s3"
    config = {
        bucket   = var.default_state_bucket
        key      = "terraform/deployment/accounts/${var.clp_account}/global/iam/ecsTaskExecutionRole/terraform.tfstate"
        region   = var.default_region
        role_arn = var.provider_role_arn
    }
}

data terraform_remote_state vpc {
    backend = "s3"
    config = {
        bucket   = var.default_state_bucket
        key      = "terraform/deployment/accounts/${var.clp_account}/regions/${var.clp_region}/network/vpc/terraform.tfstate"
        region   = var.default_region
        role_arn = var.provider_role_arn
    }
}

data terraform_remote_state sg {
    backend = "s3"
    config = {
        bucket   = var.default_state_bucket
        key      = "terraform/deployment/accounts/${var.clp_account}/regions/${var.clp_region}/network/security_groups/terraform.tfstate"
        region   = var.default_region
        role_arn = var.provider_role_arn
    }
}

data terraform_remote_state s3_tf_artefacts {
    backend = "s3"
    config = {
        bucket   = var.default_state_bucket
        key      = "terraform/deployment/accounts/${var.clp_account}/regions/${var.clp_region}/datastores/s3_tf_artefacts/terraform.tfstate"
        region   = var.default_region
        role_arn = var.provider_role_arn
    }
}

data terraform_remote_state regional_secrets {
    backend = "s3"
    config = {
        bucket   = var.default_state_bucket
        key      = "terraform/deployment/accounts/${var.clp_account}/regions/${var.clp_region}/secrets/terraform.tfstate"
        region   = var.default_region
        role_arn = var.provider_role_arn
    }
}
