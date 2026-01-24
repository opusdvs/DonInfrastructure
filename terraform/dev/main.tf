resource "twc_k8s_cluster" "k8s-cluster" {
  name           = var.cluster_name
  description    = var.cluster_description
  network_driver = var.cluster_network_driver
  version        = var.cluster_version

  preset_id  = data.twc_k8s_preset.k8s-preset-master.id
  project_id = data.twc_projects.dev.id
}

resource "twc_k8s_node_group" "k8s-cluster-node-group" {
  count = length(var.node_group_name)
  cluster_id = twc_k8s_cluster.k8s-cluster.id
  name       = "${var.node_group_name[count.index]}"
  preset_id  = data.twc_k8s_preset.k8s-preset-node.id
  node_count = var.node_group_node_count
}

resource "local_file" "kubeconfig" {
  content  = twc_k8s_cluster.k8s-cluster.kubeconfig
  filename = "${var.home_dir}/kubeconfig-${twc_k8s_cluster.k8s-cluster.name}.yaml"
}
