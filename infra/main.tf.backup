resource "aws_vpc" "sammy_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "sammy-vpc"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.sammy_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "sammy-public-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.sammy_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "sammy-public-2"
  }
}

resource "aws_internet_gateway" "sammy_igw" {
  vpc_id = aws_vpc.sammy_vpc.id

  tags = {
    Name = "sammy-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.sammy_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sammy_igw.id
  }

  tags = {
    Name = "sammy-public-rt"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "alb_sg" {
  name   = "sammy-alb-sg"
  vpc_id = aws_vpc.sammy_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sammy-alb-sg"
  }
}

resource "aws_security_group" "ecs_sg" {
  name   = "sammy-ecs-sg"
  vpc_id = aws_vpc.sammy_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sammy-ecs-sg"
  }
}

resource "aws_lb" "sammy_alb" {
  name               = "sammy-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]

  tags = {
    Name = "sammy-alb"
  }
}

resource "aws_lb_target_group" "sammy_tg" {
  name        = "sammy-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.sammy_vpc.id
  target_type = "ip"

  health_check {
    path = "/health"
  }

  tags = {
    Name = "sammy-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.sammy_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_ecr_repository" "sammy_ecr" {
  name = "sammypulse"

  tags = {
    Name = "sammypulse"
  }
}

resource "aws_ecs_cluster" "sammy_cluster" {
  name = "sammypulse-cluster"

  tags = {
    Name = "sammypulse-cluster"
  }
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
      image     = "${aws_ecr_repository.sammy_ecr.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
    }
  ])
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

resource "aws_ecs_service" "sammy_service" {
  name            = "sammypulse-service"
  cluster         = aws_ecs_cluster.sammy_cluster.id
  task_definition = aws_ecs_task_definition.sammy_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.public_subnet_1.id,
      aws_subnet.public_subnet_2.id
    ]

    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.sammy_tg.arn
    container_name   = "sammypulse"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.http
  ]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.sammy_alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = "arn:aws:acm:eu-west-2:258924246281:certificate/81e5bd70-dd5d-4b5e-9214-5e8732dad35e"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sammy_tg.arn
  }
}
