terraform {
  backend "s3" {
    bucket = "terraform-state-bucketxyz123"
    key    = "devops/terraform.tfstate"
    region = "us-east-2"
  }
}
