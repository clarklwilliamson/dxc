provider "aws" {
  region = "us-east-1"
}
resource "aws_vpc" "dxc_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "dxc-vpc"
  }
}

resource "aws_internet_gateway" "dxc_igw" {
  vpc_id = aws_vpc.dxc_vpc.id

  tags = {
    Name = "dxc-igw"
  }
}

resource "aws_subnet" "dxc_subnet1" {
  vpc_id                  = aws_vpc.dxc_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "dxc-subnet1"
  }
}

resource "aws_subnet" "dxc_subnet2" {
  vpc_id                  = aws_vpc.dxc_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b" # Change to your desired availability zone
  map_public_ip_on_launch = false

  tags = {
    Name = "dxc-subnet2"
  }
}

resource "aws_security_group" "dxc_security_group" {
  vpc_id = aws_vpc.dxc_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dxc-security-group"
  }
}
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.dxc_vpc.id
}
resource "aws_route_table_association" "gw_association" {
  subnet_id      = aws_subnet.dxc_subnet1.id
  route_table_id = aws_vpc.dxc_vpc.default_route_table_id
}

resource "aws_default_route_table" "dxc_vpc" {
  default_route_table_id = aws_vpc.dxc_vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dxc_igw.id
  }
}

resource "aws_ecs_cluster" "dxc_demo_cluster" {
  name = "dxc-demo"
}
resource "aws_ecs_task_definition" "dxcdemo" {
  family                   = "nginx-task-dxc"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu                = "256"
  memory             = "512"
  execution_role_arn = "arn:aws:iam::265021040603:role/ecsTaskExecutionRole"

  container_definitions = jsonencode([
    {
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true"
          awslogs-group         = "/ecs/nginx-task-dxc"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
        secretOptions = []
      }
      name  = "clark-dxc"
      image = "public.ecr.aws/k9n9g5s7/clark-dxc"
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}
resource "aws_ecs_service" "nginx_service" {
  name            = "nginx-service"
  cluster         = aws_ecs_cluster.dxc_demo_cluster.id
  task_definition = aws_ecs_task_definition.dxcdemo.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = [aws_subnet.dxc_subnet1.id, aws_subnet.dxc_subnet2.id]
    security_groups = [aws_security_group.dxc_security_group.id, aws_default_security_group.default.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.dxc_target_group.arn
    container_name   = "clark-dxc"
    container_port   = 80
  }

  depends_on = [aws_ecs_cluster.dxc_demo_cluster]
}
resource "aws_lb" "dxc_demo_alb" {
  name                       = "dxc-demo-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.dxc_security_group.id]
  subnets                    = [aws_subnet.dxc_subnet1.id, aws_subnet.dxc_subnet2.id]
  enable_deletion_protection = false
  enable_http2               = true
}

resource "aws_lb_target_group" "dxc_target_group" {

  name        = "dxc-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.dxc_vpc.id
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