# technologylab

## kubernetes cluster

cluster nodes are a mix of proxmox vms and physical machines

proxmox vms can be created using terraform in this repo, physical machines need to be prepared manually unfortunately

proxmox vm clone from a tempalted ubuntu server via cloud-init

the physical machines need os to be installed and configured manually

once the machines are ready, we generate the needed config for ansible to deploy kubernetes

