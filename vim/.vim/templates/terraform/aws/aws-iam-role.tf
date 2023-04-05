resource "aws_iam_role" "todo_role_name" {
  name                = ""
  tags                = {}
  assume_role_policy  = data.aws_iam_policy.todo_assume_role.json
  managed_policy_arns = []
}
