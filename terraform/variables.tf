variable "name_tag" {
  description = "Prefix for resource names"
  default     = "hw26"
}

variable "region" {
  description = "AWS region"
  default     = "eu-north-1"
}

variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_1" {
  description = "CIDR block for first subnet"
  default     = "10.0.1.0/24"
}

variable "subnet_cidr_2" {
  description = "CIDR block for second subnet"
  default     = "10.0.2.0/24"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  default     = "ami-0a2370e7c0f21e179"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.micro"
}