# First, we need a role to play with Lambda
resource "aws_iam_role" "iam_role_for_lambda" {
  name = "iam_role_for_lambda"

  //特别要注意这里的格式 <<EOF 是一整体，其中的 JSON 在下行一定要顶格写
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Here is a first lambda function that will run the code `test_lambda.handler`
module "lambda" {
  source  = "./lambda"
  name    = "test_lambda"
  runtime = "python2.7"
  role    = "${aws_iam_role.iam_role_for_lambda.arn}"
}

# This is a second lambda function that will run the code
# `test_lambda.post_handler`
module "lambda_post" {
  source  = "./lambda"
  name    = "test_lambda"
  handler = "post_handler"
  runtime = "python2.7"
  role    = "${aws_iam_role.iam_role_for_lambda.arn}"
}

# Now, we need an API to expose those functions publicly
resource "aws_api_gateway_rest_api" "test_api" {
  name = "Test API"
}

# The API requires at least one "endpoint", or "resource" in AWS terminology.
# The endpoint created here is: /test
resource "aws_api_gateway_resource" "test_api_res_test" {
  rest_api_id = "${aws_api_gateway_rest_api.test_api.id}"
  parent_id   = "${aws_api_gateway_rest_api.test_api.root_resource_id}"
  path_part   = "test"
}

# Until now, the resource created could not respond to anything. We must set up
# a HTTP method (or verb) for that!
# This is the code for method GET /test, that will talk to the first lambda
module "test_get" {
  source      = "./api_method"
  rest_api_id = "${aws_api_gateway_rest_api.test_api.id}"
  resource_id = "${aws_api_gateway_resource.test_api_res_test.id}"
  method      = "GET"
  path        = "${aws_api_gateway_resource.test_api_res_test.path}"
  lambda      = "${module.lambda.name}"
  region      = "${var.aws_region}"
  account_id  = "${var.aws_account_id}"
}

# This is the code for method POST /test, that will talk to the second lambda
module "test_post" {
  source      = "./api_method"
  rest_api_id = "${aws_api_gateway_rest_api.test_api.id}"
  resource_id = "${aws_api_gateway_resource.test_api_res_test.id}"
  method      = "POST"
  path        = "${aws_api_gateway_resource.test_api_res_test.path}"
  lambda      = "${module.lambda_post.name}"
  region      = "${var.aws_region}"
  account_id  = "${var.aws_account_id}"
}

# We can deploy the API now! (i.e. make it publicly available)
resource "aws_api_gateway_deployment" "test_api_deployment" {
  rest_api_id = "${aws_api_gateway_rest_api.test_api.id}"
  stage_name  = "production"
  description = "Deploy methods: ${module.test_get.http_method} ${module.test_post.http_method}"
}
