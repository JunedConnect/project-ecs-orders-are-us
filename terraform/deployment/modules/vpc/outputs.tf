output "vpc_id" {
  value = aws_vpc.this.id
}


output "public-subnet-ids" {
  value = [
    aws_subnet.publicsubnet1.id,
    aws_subnet.publicsubnet2.id
  ]
}

output "private-subnet-ids" {
  value = [
    aws_subnet.privatesubnet1.id,
    aws_subnet.privatesubnet2.id
  ]
}

output "vpc_endpoint_security_group_id" {
  value = aws_security_group.vpc-endpoint.id
}
