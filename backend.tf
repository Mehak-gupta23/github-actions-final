terraform {

  backend "s3" {

    bucket = "mehak-github-runner-tfstate-1234"

    key = "github-runner/terraform.tfstate"

    region = "ap-south-1"
  }
}
