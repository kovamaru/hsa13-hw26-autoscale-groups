provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags       = { Name = "${var.name_tag}-vpc" }
}

resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr_1
  availability_zone = "${var.region}a"
  tags              = { Name = "${var.name_tag}-subnet-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr_2
  availability_zone = "${var.region}b"
  tags              = { Name = "${var.name_tag}-subnet-2" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name_tag}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.name_tag}-rt" }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.name_tag}-sg" }
}

resource "aws_launch_template" "web" {
  name_prefix   = "${var.name_tag}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = "hw26-key"
  user_data     = base64encode(<<-EOF
                #!/bin/bash
                yum update -y
                yum install -y httpd
                systemctl start httpd
                systemctl enable httpd
                echo "Hello from $(hostname -f)" > /var/www/html/index.html
                EOF
  )
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }
}

resource "aws_lb" "web" {
  name               = "${var.name_tag}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "web" {
  name     = "${var.name_tag}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_autoscaling_group" "web" {
  name                = "${var.name_tag}-asg"
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns   = [aws_lb_target_group.web.arn]
  min_size            = 1
  max_size            = 8

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.web.id
        version            = "$Latest"
      }
    }
    instances_distribution {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "lowest-price"
    }
  }
}

resource "aws_autoscaling_policy" "cpu_based" {
  name                   = "${var.name_tag}-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.name_tag}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out if CPU > 70%"
  alarm_actions       = [aws_autoscaling_policy.cpu_based.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

resource "aws_autoscaling_policy" "request_based" {
  name                   = "${var.name_tag}-request-scaling"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "StepScaling"
  adjustment_type        = "ExactCapacity"
  metric_aggregation_type = "Average"

  step_adjustment {
    metric_interval_lower_bound = 0
    metric_interval_upper_bound = 100
    scaling_adjustment          = 2
  }
  step_adjustment {
    metric_interval_lower_bound = 100
    metric_interval_upper_bound = 500
    scaling_adjustment          = 4
  }
  step_adjustment {
    metric_interval_lower_bound = 500
    scaling_adjustment          = 8
  }
}

resource "aws_autoscaling_policy" "request_based_down" {
  name                   = "${var.name_tag}-request-scaling-down"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "StepScaling"
  adjustment_type        = "ExactCapacity"
  metric_aggregation_type = "Average"

  step_adjustment {
    metric_interval_upper_bound = 0
    scaling_adjustment          = 1
  }
}

resource "aws_cloudwatch_metric_alarm" "request_high" {
  alarm_name          = "${var.name_tag}-request-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 120
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Scale out if requests > 100"
  alarm_actions       = [aws_autoscaling_policy.request_based.arn]
  ok_actions          = [aws_autoscaling_policy.request_based_down.arn]
  dimensions = {
    LoadBalancer = aws_lb.web.arn_suffix
  }
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.web.dns_name
}