data "twc_k8s_preset" "k8s-preset-master" {
   cpu = 4
   type = "master"
}
data "twc_k8s_preset" "k8s-preset-node" {
   cpu = 2
   type = "worker"
}
