variable "vpc_id" {}
variable "subnet_ids" {}
variable "alb_sg_id" {}
variable "certificate_arn" {}

resource "aws_lb" "sammy_alb" {
  name               = "sammy-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.subnet_ids

  tags = {
    Name = "sammy-alb"
  }
}

resource "aws_lb_target_group" "sammy_tg" {
  name        = "sammy-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
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

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.sammy_alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sammy_tg.arn
  }
}