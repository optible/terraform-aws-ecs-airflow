variable "namespace_id" {
  type        = string
  description = "namespace_id"
}
variable "region" {
  type        = string
  description = "The region to deploy your solution to"
  default     = "eu-west-1"
}

variable "resource_prefix" {
  type        = string
  description = "A prefix for the create resources, example your company name (be aware of the resource name length)"
}

variable "resource_suffix" {
  type        = string
  description = "A suffix for the created resources, example the environment for airflow to run in (be aware of the resource name length)"
}

variable "extra_tags" {
  description = "Extra tags that you would like to add to all created resources"
  type        = map(string)
  default     = {}
}

// Airflow variables
variable "airflow_image_name" {
  type        = string
  description = "The name of the airflow image"
  default     = "apache/airflow"
}

variable "airflow_image_tag" {
  type        = string
  description = "The tag of the airflow image"
  default     = "2.0.1"
}

variable "airflow_executor" {
  type        = string
  description = "The executor mode that airflow will use. Only allowed values are [\"Local\", \"Sequential\"]. \"Local\": Run DAGs in parallel (will created a RDS); \"Sequential\": You can not run DAGs in parallel (will NOT created a RDS);"
  default     = "Local"

  validation {
    condition     = contains(["Local", "Sequential"], var.airflow_executor)
    error_message = "The only values that are allowed for \"airflow_executor\" are [\"Local\", \"Sequential\"]."
  }
}

variable "airflow_authentication" {
  type        = string
  description = "Authentication backend to be used, supported backends [\"\", \"rbac\"]. When \"rbac\" is selected an admin role is create if there are no other users in the db, from here you can create all the other users. Make sure to change the admin password directly upon first login! (if you don't change the rbac_admin options the default login is => username: admin, password: admin)"
  default     = ""

  validation {
    condition     = contains(["", "rbac"], var.airflow_authentication)
    error_message = "The only values that are allowed for \"airflow_executor\" are [\"\", \"rbac\"]."
  }
}

variable "airflow_py_requirements_path" {
  type        = string
  description = "The relative path to a python requirements.txt file to install extra packages in the container that you can use in your DAGs."
  default     = ""
}

variable "airflow_variables" {
  type        = map(string)
  description = "The variables passed to airflow as an environment variable (see airflow docs for more info https://airflow.apache.org/docs/). You can not specify \"AIRFLOW__CORE__SQL_ALCHEMY_CONN\" and \"AIRFLOW__CORE__EXECUTOR\" (managed by this module)"
  default     = {}
}

variable "airflow_container_home" {
  type        = string
  description = "Working dir for airflow (only change if you are using a different image)"
  default     = "/opt/airflow"
}

variable "airflow_log_region" {
  type        = string
  description = "The region you want your airflow logs in, defaults to the region variable"
  default     = ""
}

variable "airflow_log_retention" {
  type        = string
  description = "The number of days you want to keep the log of airflow container"
  default     = "7"
}

variable "airflow_example_dag" {
  type        = bool
  description = "Add an example dag on startup (mostly for sanity check)"
  default     = true
}

// RBAC
variable "rbac_admin_username" {
  type        = string
  description = "RBAC Username (only when airflow_authentication = 'rbac')"
  default     = "admin"
}

variable "rbac_admin_password" {
  type        = string
  description = "RBAC Password (only when airflow_authentication = 'rbac')"
  default     = "admin"
}

variable "rbac_admin_email" {
  type        = string
  description = "RBAC Email (only when airflow_authentication = 'rbac')"
  default     = "admin@admin.com"
}

variable "rbac_admin_firstname" {
  type        = string
  description = "RBAC Firstname (only when airflow_authentication = 'rbac')"
  default     = "admin"
}

variable "rbac_admin_lastname" {
  type        = string
  description = "RBAC Lastname (only when airflow_authentication = 'rbac')"
  default     = "airflow"
}

// ECS variables
variable "ecs_cpu" {
  type        = number
  description = "The allocated cpu for your airflow instance"
  default     = 1024
}

variable "ecs_memory" {
  type        = number
  description = "The allocated memory for your airflow instance"
  default     = 2048
}

// Networking variables
variable "ip_allow_list" {
  type        = list(string)
  description = "A list of ip ranges that are allowed to access the airflow webserver, default: full access"
  default     = ["0.0.0.0/0"]
}

variable "vpc_id" {
  type        = string
  description = "The id of the vpc where you will run ECS/RDS"

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "The vpc_id value must be a valid VPC id, starting with \"vpc-\"."
  }
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "A list of subnet ids of where the ECS and RDS reside, this will only work if you have a NAT Gateway in your VPC"
  default     = []

  validation {
    condition     = length(var.private_subnet_ids) >= 2 || length(var.private_subnet_ids) == 0
    error_message = "The size of the list \"private_subnet_ids\" must be at least 2 or empty."
  }
}

// Database variables
variable "postgres_uri" {
  type        = string
  description = "The postgres uri of your postgres db, if none provided a postgres db in rds is made. Format \"<db_username>:<db_password>@<db_endpoint>:<db_port>/<db_name>\""
  default     = ""
}

// S3 Bucket
variable "s3_bucket_name" {
  type        = string
  default     = ""
  description = "The S3 bucket name where the DAGs and startup scripts will be stored, leave this blank to let this module create a s3 bucket for you. WARNING: this module will put files into the path \"dags/\" and \"startup/\" of the bucket"
}

variable "managed_policy_ecs_task_arn" {
  type = list(string)
  default = []
}