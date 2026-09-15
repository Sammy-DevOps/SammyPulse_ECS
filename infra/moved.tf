moved {
  from = aws_vpc.sammy_vpc
  to   = module.network.aws_vpc.sammy_vpc
}

moved {
  from = aws_subnet.public_subnet_1
  to   = module.network.aws_subnet.public_subnet_1
}

moved {
  from = aws_subnet.public_subnet_2
  to   = module.network.aws_subnet.public_subnet_2
}

moved {
  from = aws_internet_gateway.sammy_igw
  to   = module.network.aws_internet_gateway.sammy_igw
}

moved {
  from = aws_route_table.public_rt
  to   = module.network.aws_route_table.public_rt
}

moved {
  from = aws_route_table_association.public_1
  to   = module.network.aws_route_table_association.public_1
}

moved {
  from = aws_route_table_association.public_2
  to   = module.network.aws_route_table_association.public_2
}

moved {
  from = aws_security_group.alb_sg
  to   = module.network.aws_security_group.alb_sg
}

moved {
  from = aws_security_group.ecs_sg
  to   = module.network.aws_security_group.ecs_sg
}

moved {
  from = aws_lb.sammy_alb
  to   = module.alb.aws_lb.sammy_alb
}

moved {
  from = aws_lb_target_group.sammy_tg
  to   = module.alb.aws_lb_target_group.sammy_tg
}

moved {
  from = aws_lb_listener.http
  to   = module.alb.aws_lb_listener.http
}

moved {
  from = aws_lb_listener.https
  to   = module.alb.aws_lb_listener.https
}

moved {
  from = aws_ecr_repository.sammy_ecr
  to   = module.ecr.aws_ecr_repository.sammy_ecr
}

moved {
  from = aws_ecs_cluster.sammy_cluster
  to   = module.ecs.aws_ecs_cluster.sammy_cluster
}

moved {
  from = aws_iam_role.ecs_execution_role
  to   = module.ecs.aws_iam_role.ecs_execution_role
}

moved {
  from = aws_iam_role_policy_attachment.ecs_execution_role_policy
  to   = module.ecs.aws_iam_role_policy_attachment.ecs_execution_role_policy
}

moved {
  from = aws_ecs_task_definition.sammy_task
  to   = module.ecs.aws_ecs_task_definition.sammy_task
}

moved {
  from = aws_ecs_service.sammy_service
  to   = module.ecs.aws_ecs_service.sammy_service
}
