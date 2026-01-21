data "twc_k8s_preset" "k8s-preset-master" {
  cpu      = var.cpu
  type     = "master"
  location = var.region
}
data "twc_k8s_preset" "k8s-preset-node" {
  cpu      = var.cpu
  type     = "worker"
  location = var.region
}

data "twc_projects" "services" {
  name = var.project_name
}