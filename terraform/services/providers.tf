terraform {
  required_providers {
    twc = {
      source = "tf.timeweb.cloud/timeweb-cloud/timeweb-cloud"
      version = "~> 1.6.9"
    }
    selectel = {
      source = "selectel/selectel"
      version = "~> 6.0"
    }
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "~> 2.1.0"
    }
  }
}

provider "twc" {}
provider "selectel" {}
provider "openstack" {}