resource "aws_iam_policy" "todo_policy_name" {
  name   = "TODO-Policy-Name"
  tags   = { Jira = "" }
  policy = data.aws_iam_policy_document.todo_policy_name.json
}

data "aws_iam_policy_document" "todo_policy_name" {
  statement {
    effect    = "Allow"
    actions   = []
    resources = []
  }
}
