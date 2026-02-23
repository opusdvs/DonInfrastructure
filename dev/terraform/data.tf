data "twc_k8s_preset" "k8s-preset-master" {
  cpu      = var.node_group_cpu
  type     = "master"
  location = var.region
}

data "twc_k8s_preset" "k8s-preset-node" {
  cpu      = var.node_group_cpu
  type     = "worker"
  location = var.region
}

data "twc_projects" "dev" {
  name = var.project_name
}
