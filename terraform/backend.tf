terraform {
  backend "s3" {
    bucket                      = "2d25c8ae-dev-terraform-state"
    key                         = "terraform.tfstate"
    endpoint                    = "https://s3.twcstorage.ru"
    region                      = "ru-1"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}