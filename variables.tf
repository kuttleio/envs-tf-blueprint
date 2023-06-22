variable env_tags {}
variable global_tags {}
variable account_id {}
variable ecr_region {}
variable clp_region {}
variable clp_account {}
variable domain_name {}
variable default_region {}
variable mezmo_account_id {}
variable provider_role_arn {}
variable default_state_bucket {}
variable aws_provider_session_name {}
variable clp_zenv {
    default = "ktl1"
}
variable allowed_cidr_blocks {
    default = ["0.0.0.0/0"]
}

# ---------------------------------------------------
#   DB Variables
# ---------------------------------------------------
variable "engine" {
  default = "aurora-postgresql"
}
variable "engine_version" {
  default = "15.2"
}
variable "cluster_family" {
  default = "aurora-postgresql14"
}
variable "cluster_size" {
  default = 1
}
variable "admin_user" {
  default = "kuttle"
}
variable "db_name" {
  default = "manifests"
}
variable "db_port" {
  default = 5432
}
variable "instance_type" {
  default = "db.t4g.medium"
}
variable "autoscaling_enabled" {
  default = false
}
