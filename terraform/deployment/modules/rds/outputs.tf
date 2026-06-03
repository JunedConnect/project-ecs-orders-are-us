output "connection_url" {
  value     = "postgres://foo:foobarbaz@${aws_db_instance.this.address}:${aws_db_instance.this.port}/${aws_db_instance.this.db_name}"
  sensitive = true
}
