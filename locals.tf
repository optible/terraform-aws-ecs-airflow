locals {
  auth_map = {
    "rbac" = "airflow.contrib.auth.backends.password_auth"
  }

  own_tags = {
    Name      = "${var.resource_prefix}-airflow-${var.resource_suffix}"
    CreatedBy = "Terraform"
    Module    = "terraform-aws-ecs-airflow"
  }
  common_tags = merge(local.own_tags, var.extra_tags)

  timestamp           = timestamp()
  timestamp_sanitized = replace(local.timestamp, "/[- TZ:]/", "")
  year                = formatdate("YYYY", local.timestamp)
  month               = formatdate("M", local.timestamp)
  day                 = formatdate("D", local.timestamp)

  db_uri = var.postgres_uri

  s3_bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : aws_s3_bucket.airflow[0].id
  s3_key         = ""

  airflow_py_requirements_path     = var.airflow_py_requirements_path != "" ? var.airflow_py_requirements_path : "${path.module}/templates/startup/requirements.txt"
  airflow_log_region               = var.airflow_log_region != "" ? var.airflow_log_region : var.region
  airflow_webserver_container_name = "${var.resource_prefix}-airflow-webserver-${var.resource_suffix}"
  airflow_scheduler_container_name = "${var.resource_prefix}-airflow-scheduler-${var.resource_suffix}"
  airflow_sidecar_container_name   = "${var.resource_prefix}-airflow-sidecar-${var.resource_suffix}"
  airflow_init_container_name      = "${var.resource_prefix}-airflow-init-${var.resource_suffix}"
  airflow_volume_name              = "airflow"
  // Keep the 2 env vars second, we want to override them (this module manges these vars)
  airflow_variables = merge(var.airflow_variables, {
    AIRFLOW__CORE__SQL_ALCHEMY_CONN : local.db_uri,
    AIRFLOW__CORE__EXECUTOR : "${var.airflow_executor}Executor",
    AIRFLOW__WEBSERVER__RBAC : var.airflow_authentication == "" ? false : true,
    AIRFLOW__API__AUTH_BACKEND : "airflow.api.auth.backend.basic_auth",
    AIRFLOW__WEBSERVER__AUTH_BACKEND : lookup(local.auth_map, var.airflow_authentication, "")
    AIRFLOW__WEBSERVER__BASE_URL : "http://airflow.optible.internal:8080" # localhost is default value
  })

  airflow_variables_list = formatlist("{\"name\":\"%s\",\"value\":\"%s\"}", keys(local.airflow_variables), values(local.airflow_variables))

  rds_ecs_subnet_ids = var.private_subnet_ids
  inbound_ports      = "80"
}
