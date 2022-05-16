data "aws_iam_policy_document" "task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# role for ecs to create the instance
resource "aws_iam_role" "execution" {
  name               = "${var.resource_prefix}-airflow-task-execution-role-${var.resource_suffix}"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = local.common_tags
}

# role for the airflow instance itself
resource "aws_iam_role" "task" {
  name                = "${var.resource_prefix}-airflow-task-role-${var.resource_suffix}"
  assume_role_policy  = data.aws_iam_policy_document.task_assume.json
  managed_policy_arns = var.managed_policy_ecs_task_arn
  tags                = local.common_tags
}
