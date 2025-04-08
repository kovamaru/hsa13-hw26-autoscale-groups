# hsa13-hw26-autoscale-groups
Create autoscale group that will contain one ondemand instance and will scale on spot instances.  Set up scaling policy based on AVG CPU usage.  Set up scaling policy based on requests amount that allows non-linear growth.

# AWS Auto Scaling Group Setup with Terraform

This is my homework assignment (HW26) for setting up an AWS Auto Scaling Group (ASG) using Terraform. I created an infrastructure that includes an ASG with one On-Demand instance and scaling via Spot Instances, along with two scaling policies: one based on CPU usage and another based on request count with non-linear growth. In this README, I’ll describe what I did, how to deploy the project, how to test the scaling, and show my results.

## What I Did

### Infrastructure Overview
I set up the following infrastructure:
- **VPC**: Created a VPC with two public subnets in the `eu-north-1` (Stockholm) region:
    - Subnet 1: `10.0.1.0/24` (eu-north-1a).
    - Subnet 2: `10.0.2.0/24` (eu-north-1b).
- **Application Load Balancer (ALB)**: The ALB distributes traffic to EC2 instances in the ASG. It listens on port 80 and forwards requests to a Target Group.
- **Auto Scaling Group (ASG)**:
    - Name: `hw26-dev-asg`.
    - Minimum size: 1 instance.
    - Maximum size: 8 instances.
    - One On-Demand instance, with additional instances being Spot Instances.
    - Used a Launch Template with the Amazon Linux 2 AMI (`ami-02707c2f0f2e179b4`) and `t3.micro` instance type.
    - Added a `user_data` script in the Launch Template that:
        - Updates the system (`yum update -y`).
        - Installs a web server (`yum install -y httpd`).
        - Starts and enables `httpd` (`systemctl start httpd`, `systemctl enable httpd`).
        - Creates an `index.html` page with the text "Hello from <hostname>".
- **Scaling Policies**:
    - **CPU-based (linear growth)**: If the average CPU usage exceeds 30% for 4 minutes, the ASG adds 1 instance.
    - **Request-based (non-linear growth)**: Based on the number of requests to the ALB:
        - 0–100 requests: 2 instances.
        - 100–500 requests: 4 instances.
        - 500 requests: 8 instances.
    - **Scale-in policy**: When the request count drops below 100, the ASG reduces the capacity to 1 instance.
