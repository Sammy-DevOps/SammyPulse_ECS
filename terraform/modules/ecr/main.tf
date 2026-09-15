resource "aws_ecr_repository" "sammy_ecr" {
  name = "gatus"

  tags = {
    Name = "sammypulse"
  }
}
