resource "twc_k8s_cluster" "k8s-cluster" {
  name           = var.cluster_name
  description    = var.cluster_description
  network_driver = var.cluster_network_driver
  version        = var.cluster_version

  preset_id  = var.cluster_preset_id
  project_id = var.project_id
}

resource "twc_k8s_node_group" "k8s-cluster-node-group" {
  count = length(var.node_group_name)
  cluster_id = twc_k8s_cluster.k8s-cluster.id
  name       = var.node_group_name[count.index]
  preset_id  = var.node_group_preset_id
  node_count = var.node_group_node_count
}