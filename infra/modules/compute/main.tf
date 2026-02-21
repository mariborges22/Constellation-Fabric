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

resource "aws_ecr_repository" "combat" {
  name                 = "constellation-combat"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-combat-repo"
  }
}

resource "aws_ecr_repository" "event_publisher" {
  name                 = "constellation-event-publisher"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-event-publisher-repo"
  }
}

