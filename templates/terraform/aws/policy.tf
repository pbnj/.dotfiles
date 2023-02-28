resource "aws_iam_policy" "policy_name" {
  name = "Policy-Name"
  tags = { Jira = "" }
  policy = jsonencode(
    {
      Statement = [
        {
          Effect   = "Allow"
          Action   = []
          Resource = []
        }
      ]
      Version = "2012-10-17"
    }
  )
}
