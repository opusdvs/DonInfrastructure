locals {
  enable_twc_k8s = var.enable_twc_k8s ? 1 : 0
}

module "twc_k8s" {
  count = local.enable_twc_k8s
  source = "../../terraform-module/twc/twc_k8s"
  cluster_name = var.cluster_name
  cluster_description = var.cluster_description
  cluster_network_driver = var.cluster_network_driver
  cluster_version = var.cluster_version
  node_group_name = var.node_group_name
  network_driver = var.cluster_network_driver
  cluster_preset_id = data.twc_k8s_preset.k8s-preset-master.id
  project_id = data.twc_projects.services.id
  node_group_cpu = var.node_group_cpu
  node_group_preset_id = data.twc_k8s_preset.k8s-preset-node.id
  node_group_node_count = var.node_group_node_count
}

resource "local_file" "kubeconfig" {
  content = module.twc_k8s[0].kubeconfig
  filename = "kubeconfig_${var.cluster_name}.yaml"
}