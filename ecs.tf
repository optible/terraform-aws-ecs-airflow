resource "aws_ecs_cluster" "airflow" {
  name               = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
  }

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "airflow" {
  family                   = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.execution.arn

  volume {
    name = local.airflow_volume_name
  }
  container_definitions = <<TASK_DEFINITION
    [
      {
        "cpu": 0,
        "volumesFrom": [],
        "image": "mikesir87/aws-cli",
        "name": "${local.airflow_sidecar_container_name}",
        "command": [
            "/bin/bash -c \"aws s3 cp s3://${local.s3_bucket_name}/${local.s3_key} ${var.airflow_container_home} --recursive && chmod +x ${var.airflow_container_home}/${aws_s3_bucket_object.airflow_scheduler_entrypoint.key} && chmod +x ${var.airflow_container_home}/${aws_s3_bucket_object.airflow_webserver_entrypoint.key} && chmod -R 777 ${var.airflow_container_home}\""
        ],
        "entryPoint": [
            "sh",
            "-c"
        ],
        "essential": false,
        "mountPoints": [
          {
            "sourceVolume": "${local.airflow_volume_name}",
            "containerPath": "${var.airflow_container_home}"
          }
        ],
        "portMapping": [],
        "environment": []
      },
      {
        "image": "${var.airflow_image_name}:${var.airflow_image_tag}",
        "name": "${local.airflow_init_container_name}",
        "dependsOn": [
            {
                "containerName": "${local.airflow_sidecar_container_name}",
                "condition": "SUCCESS"
            }
        ],
        "command": [
            "/bin/bash -c \"${var.airflow_container_home}/${aws_s3_bucket_object.airflow_init_entrypoint.key}\""
        ],
        "entryPoint": [
            "sh",
            "-c"
        ],
        "environment": [
          ${join(",\n", formatlist("{\"name\":\"%s\",\"value\":\"%s\"}", keys(local.airflow_variables), values(local.airflow_variables)))}
        ],
        "essential": false,
        "mountPoints": [
          {
            "sourceVolume": "${local.airflow_volume_name}",
            "containerPath": "${var.airflow_container_home}"
          }
        ],
        "cpu": 0,
        "volumesFrom": [],
        "portMapping": []
      },
      {
        "image": "${var.airflow_image_name}:${var.airflow_image_tag}",
        "name": "${local.airflow_scheduler_container_name}",
        "dependsOn": [
            {
                "containerName": "${local.airflow_sidecar_container_name}",
                "condition": "SUCCESS"
            },
            {
                "containerName": "${local.airflow_init_container_name}",
                "condition": "SUCCESS"
            }
        ],
        "command": [
            "/bin/bash -c \"${var.airflow_container_home}/${aws_s3_bucket_object.airflow_scheduler_entrypoint.key}\""
        ],
        "entryPoint": [
            "sh",
            "-c"
        ],
        "environment": [
          ${join(",\n", formatlist("{\"name\":\"%s\",\"value\":\"%s\"}", keys(local.airflow_variables), values(local.airflow_variables)))}
        ],
        "essential": true,
        "mountPoints": [
          {
            "sourceVolume": "${local.airflow_volume_name}",
            "containerPath": "${var.airflow_container_home}"
          }
        ],
        "cpu": 0,
        "volumesFrom": [],
        "portMapping": []
      },
      {
        "image": "${var.airflow_image_name}:${var.airflow_image_tag}",
        "name": "${local.airflow_webserver_container_name}",
        "dependsOn": [
            {
                "containerName": "${local.airflow_sidecar_container_name}",
                "condition": "SUCCESS"
            },
            {
                "containerName": "${local.airflow_init_container_name}",
                "condition": "SUCCESS"
            }
        ],
        "command": [
            "/bin/bash -c \"${var.airflow_container_home}/${aws_s3_bucket_object.airflow_webserver_entrypoint.key}\""
        ],
        "entryPoint": [
            "sh",
            "-c"
        ],
        "environment": [
          ${join(",\n", formatlist("{\"name\":\"%s\",\"value\":\"%s\"}", keys(local.airflow_variables), values(local.airflow_variables)))}
        ],
        "healthCheck": {
          "command": [ "CMD-SHELL", "curl -f http://localhost:8080/health || exit 1" ],
          "startPeriod": 120,
          "interval": 30,
          "retries": 3,
          "timeout": 5
        },
        "essential": true,
        "mountPoints": [
          {
            "sourceVolume": "${local.airflow_volume_name}",
            "containerPath": "${var.airflow_container_home}"
          }
        ],
        "cpu": 0,
        "volumesFrom": [],
        "portMappings": [
            {
                "containerPort": 8080,
                "hostPort": 8080,
                "protocol": "tcp"
            }
        ]
      }
    ]
  TASK_DEFINITION

  tags = local.common_tags
}


resource "aws_service_discovery_service" "airflow" {
  name = "airflow"

  dns_config {
    namespace_id = var.namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "airflow" {
  name            = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  cluster         = aws_ecs_cluster.airflow.id
  task_definition = aws_ecs_task_definition.airflow.arn
  desired_count   = 1

  health_check_grace_period_seconds = 120

  network_configuration {
    subnets          = local.rds_ecs_subnet_ids
    assign_public_ip = length(var.private_subnet_ids) == 0 ? true : false
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }
  service_registries {
    registry_arn = aws_service_discovery_service.airflow.arn
  }
}
