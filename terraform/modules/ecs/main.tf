variable "subnet_ids" {}
variable "ecs_sg_id" {}
variable "target_group_arn" {}
variable "repository_url" {}
variable "ssm_parameter_arn" {}

resource "aws_ecs_cluster" "sammy_cluster" {
  name = "sammypulse-cluster"

  tags = {
    Name = "sammypulse-cluster"
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "sammypulse-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ssm_parameter_access" {
  name = "sammypulse-ssm-access"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters"
        ]
        Resource = var.ssm_parameter_arn
      }
    ]
  })
}

resource "aws_ecs_task_definition" "sammy_task" {
  family                   = "sammypulse-task"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "sammypulse"
      image     = "${var.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      secrets = [
        {
          name      = "DISCORD_WEBHOOK_URL"
          valueFrom = var.ssm_parameter_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = "/ecs/sammypulse"
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "sammy_service" {
  name            = "sammypulse-service"
  cluster         = aws_ecs_cluster.sammy_cluster.id
  task_definition = aws_ecs_task_definition.sammy_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "sammypulse"
    container_port   = 8080
  }
}