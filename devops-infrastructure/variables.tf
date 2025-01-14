variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "List of Availability Zones to deploy subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "docker_image" {
  description = "Docker image for the ECS task"
  type        = string
  default     = "muhalwan/devops-webapp:latest"
}

variable "container_port" {
  description = "Port on which the container listens"
  type        = number
  default     = 3000
}

variable "app_health_check_path" {
  description = "Health check path for the application"
  type        = string
  default     = "/api/items"
}

variable "database_url" {
  description = "MongoDB connection string"
  type        = string
}