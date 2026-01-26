resource "selectel_mks_cluster_v1" "servicesmks-cluster" {
  name = var.cluster_name
  project_id = ""
  region = "ru-3"
  kube_version = data.selectel_mks_kube_versions_v1.sectel-kube-versions.latest_version
  zonal = "true"
  enable_patch_version_auto_upgrade = "false"
}

resource "selectel_mks_nodegroup_v1" "services-mks-nodegroup" {
  cluster_id = selectel_mks_cluster_v1.servicesmks-cluster.id
  project_id = ""
  region = selectel_mks_cluster_v1.servicesmks-cluster.region
  availability_zone = "ru-3b"
  nodes_count = 5
  cpus = 2
  ram_mb = 4096
  volume_gb = 20
  volume_type = "fast.ru-3b"
  install_nvidia_device_plugin = "false"
}