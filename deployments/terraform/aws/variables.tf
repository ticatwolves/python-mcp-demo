variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "mcp_server_name" {
  type    = string
  default = "python-mcp-demo"
}

variable "mcp_certificate_arn" {
  type    = string
  default = ""
}

variable "env_tag" {
  type    = string
  default = "Production"
}

variable "desired_task" {
  type = number
  default = 1
}
