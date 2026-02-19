resource "aws_ecr_repository" "auth" {
  name                 = "constellation-auth"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-auth-repo"
  }
}
