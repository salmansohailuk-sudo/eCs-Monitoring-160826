# ---------------------------------------------------------
# ECR Repositories - Used later for ECS deployment
# ---------------------------------------------------------
resource "aws_ecr_repository" "repos" {
  for_each = toset(var.ecr_repo_names)

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  tags = { Name = each.value }
}
