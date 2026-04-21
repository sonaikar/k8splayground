## 1) Launch VM with cloud-init
multipass launch 22.04 -n k8s-master --cpus 2 --memory 4G --disk 30G --cloud-init cloud-init-kubeadm.yaml

## 2) Launch VM with cloud-init and bridged networking
multipass launch 22.04 -n k8s-master --cpus 2 --memory 4G --disk 30G --network en0 --cloud-init cloud-init-kubeadm.yaml


## 2) Verify control plane and pods
multipass exec k8s-master -- kubectl get nodes -o wide
multipass exec k8s-master -- kubectl get pods -A

## 3) (Optional) Pull kubeconfig to your host
multipass transfer k8s-master:/home/ubuntu/.kube/config ./kubeconfig
KUBECONFIG=./kubeconfig kubectl get nodes

### 4) kubeadm command
kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=192.168.2.8 --apiserver-cert-extra-sans=192.168.2.8