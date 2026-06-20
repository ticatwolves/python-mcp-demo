output "alb_url" {
  value = aws_lb.mcp_alb.dns_name
}
