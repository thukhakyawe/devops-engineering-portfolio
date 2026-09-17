terraform {
  backend "s3" {
    bucket       = "cloud-native-sre-terraform-state-bbdc35301f4a232f8c9047d604"
    key          = "prod/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
