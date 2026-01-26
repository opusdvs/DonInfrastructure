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

data "twc_projects" "services" {
  name = var.project_name
}

data "selectel_mks_kube_versions_v1" "sectel-kube-versions" {
  project_id = "2846c54281be4833b8f6f23991aaa1eb"
  region = "ru-3"
}