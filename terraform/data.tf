data "twc_k8s_preset" "k8s-preset-master" {
   cpu = 4
   type = "master"
   location = var.region
}
data "twc_k8s_preset" "k8s-preset-node" {
   cpu = 2
   type = "worker"
   location = var.region
}

data "twc_projects" "services" {
   name = var.project_name
}