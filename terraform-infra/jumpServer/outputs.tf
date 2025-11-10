output "bastion-sg-id" {
  value = aws_security_group.bastion_sg.id

}

output "bastion_public_ip" {
  value       = aws_instance.bastion_host.public_ip
  description = "Public IP of the bastion server"
}
