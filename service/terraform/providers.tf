terraform {
  required_providers {
    twc = {
      source = "tf.timeweb.cloud/timeweb-cloud/timeweb-cloud"
      version = "~> 1.6.9"
    }
  }
}

provider "twc" {}
