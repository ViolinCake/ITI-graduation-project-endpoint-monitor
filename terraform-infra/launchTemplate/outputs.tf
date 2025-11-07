output "launch-template-name" {
  value = aws_launch_template.demo_node_launch_template.name
}
output "launch-template-version" {
  value = aws_launch_template.demo_node_launch_template.latest_version
}
output "launch-template-id" {
  value = aws_launch_template.demo_node_launch_template.id
}