provider "aws" {
  region = "us-east-1"
}
resource "aws_ecs_cluster" "dxc_demo_cluster" {
  name = "dxc-demo"
}

resource "aws_ecs_task_definition" "nginx_task" {
  family                   = "nginx-task-dxc"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu                = "256"
  memory             = "512"
  execution_role_arn = "arn:aws:iam::265021040603:role/ecsTaskExecutionRole"
  container_definitions = jsonencode([
    {
      name  = "dxcdemo"
      image = "265021040603.dkr.ecr.us-east-1.amazonaws.com/clark-dxc:latest"
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}


resource "aws_lb" "dxc_demo_alb" {
  name                       = "dxc-demo-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = ["sg-0e3cdea17d8598683"]
  subnets                    = ["subnet-44ed8f48", "subnet-43483726"]
  enable_deletion_protection = false
  enable_http2               = true
}
resource "aws_lb_listener" "dxcdemo_listener" {
  load_balancer_arn = aws_lb.dxc_demo_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.dxc_target_group.arn
    type             = "forward"
  }
}
resource "aws_lb_target_group" "dxc_target_group" {

  name        = "dxc-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-b99eccdc"
}

resource "aws_ecs_service" "nginx_service" {
  name            = "nginx-service-dxc"
  cluster         = aws_ecs_cluster.dxc_demo_cluster.id
  task_definition = aws_ecs_task_definition.nginx_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = ["subnet-44ed8f48", "subnet-43483726"]
    security_groups = ["sg-0e3cdea17d8598683"]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.dxc_target_group.arn
    container_name   = "dxcdemo"
    container_port   = 80
  }


  depends_on = [aws_ecs_cluster.dxc_demo_cluster]
}