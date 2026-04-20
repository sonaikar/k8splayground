## Launch a small Load Balancer node (Essential for 3-node control planes)
```shell
multipass launch --name lb-node --network name=en0,mode=manual --cpus 1 -m 1G 
multipass exec lb-node -- sudo bash -c 'cat << EOF > /etc/netplan/10-custom.yaml
network:
  version: 2
  ethernets:
    extra0:
      dhcp4: no
      addresses: [10.0.0.150/24]
EOF'

multipass exec lb-node -- sudo netplan apply
multipass list
multipass shell lb-node
sudo apt-get update && sudo apt-get install -y haproxy

# HA Proxy Config 
multipass shell lb-node
sudo apt update && sudo apt install -y haproxy

#  Add this to the end of /etc/haproxy/haproxy.cfg:

frontend k8s-api
    bind 10.0.0.150:6443
    mode tcp
    option tcplog
    default_backend k8s-masters

backend k8s-masters
    mode tcp
    balance roundrobin
    option tcp-check
    server master-1 10.0.0.151:6443 check
    server master-2 10.0.0.152:6443 check
    server master-3 10.0.0.153:6443 check

listen stats
    bind :1936
    mode http
    stats enable
    stats uri /
    stats hide-version

sudo systemctl restart haproxy

```

## Master nodes
### Master 1:
```shell
multipass launch --name k8s-master-1 --network name=en0,mode=manual --cpus 2 -m 4G -d 30G
multipass exec k8s-master-1 -- sudo bash -c 'cat << EOF > /etc/netplan/10-custom.yaml
network:
  version: 2
  ethernets:
    extra0:
      dhcp4: no
      addresses: [10.0.0.151/24]
EOF'
multipass exec k8s-master-1 -- sudo netplan apply
```

### Master 2:
```shell
multipass launch --name k8s-master-2 --network name=en0,mode=manual --cpus 2 -m 4G -d 30G
multipass exec k8s-master-2 -- sudo bash -c 'cat << EOF > /etc/netplan/10-custom.yaml
network:
  version: 2
  ethernets:
    extra0:
      dhcp4: no
      addresses: [10.0.0.152/24]
EOF'
multipass exec k8s-master-1 -- sudo netplan apply
```

### Master 3:
```shell
multipass launch --name k8s-master-3 --network name=en0,mode=manual --cpus 2 -m 4G -d 30G
multipass exec k8s-master-3 -- sudo bash -c 'cat << EOF > /etc/netplan/10-custom.yaml
network:
  version: 2
  ethernets:
    extra0:
      dhcp4: no
      addresses: [10.0.0.153/24]
EOF'
multipass exec k8s-master-1 -- sudo netplan apply
```

### Configure all nodes for containers and install required binaries. 
```shell
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

sysctl --system



# Install Containerd 2.1.7

wget https://github.com/containerd/containerd/releases/download/v2.1.7/containerd-2.1.7-linux-arm64.tar.gz

tar Cxzvf /usr/local containerd-2.1.7-linux-arm64.tar.gz

wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

cp containerd.service /usr/lib/systemd/system/

systemctl daemon-reload
systemctl enable --now containerd
crictl config runtime-endpoint unix:///run/containerd/containerd.sock


wget  https://github.com/opencontainers/runc/releases/download/v1.3.5/runc.arm64
install -m 755 runc.arm64 /usr/local/sbin/runc


wget https://github.com/containernetworking/plugins/releases/download/v1.9.1/cni-plugins-linux-arm-v1.9.1.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin  cni-plugins-linux-arm-v1.9.1.tgz

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

systemctl enable --now kubelet
```
## Initialize First node
```shell
sudo kubeadm init --apiserver-advertise-address=10.0.0.151 \
--control-plane-endpoint "10.0.0.150:6443"  --pod-network-cidr=10.244.0.0/16 \
--apiserver-cert-extra-sans 10.0.0.50,lb-node,k8s-master-1,k8s-master-2,k8s-master-3 \
--upload-certs 
```


### Install Calico 
```shell
curl https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/calico.yaml -O
kubectl apply -f calico.yaml
```

## Launch worker nodes

```shell 
multipass launch --name k8s-worker-1 --network name=en0,mode=manual --cpus 2 -m 4G -d 30G
multipass exec k8s-worker-1 -- sudo bash -c 'cat << EOF > /etc/netplan/10-custom.yaml
network:
  version: 2
  ethernets:
    extra0:
      dhcp4: no
      addresses: [10.0.0.156/24]
EOF'
multipass exec k8s-worker-1 -- sudo netplan apply


multipass launch --name k8s-worker-2 --network name=en0,mode=manual --cpus 2 -m 4G -d 30G
multipass exec k8s-worker-2 -- sudo bash -c 'cat << EOF > /etc/netplan/10-custom.yaml
network:
  version: 2
  ethernets:
    extra0:
      dhcp4: no
      addresses: [10.0.0.157/24]
EOF'
multipass execk8s-worker-2 -- sudo netplan apply
```

## Kubectl join commands

```shell
# k8s-master-2 join the cluster: 
 kubeadm join 10.0.0.150:6443 --token 1blku5.lgijw9i3fprtty40 \
	--discovery-token-ca-cert-hash sha256:46b87971b06d9f09e85487b3b4ba4723c1eec186eee6f43cc407ca6079f1bf9d \
	--control-plane --certificate-key a9fef33e0b267f3cf4649dc359cd533afe8c494c29dd3362af64bf844d0a8ca7 \
--apiserver-advertise-address 10.0.0.152 

# k8s-master-3 join the cluster: 
kubeadm join 10.0.0.150:6443 --token 1blku5.lgijw9i3fprtty40 \
	--discovery-token-ca-cert-hash sha256:46b87971b06d9f09e85487b3b4ba4723c1eec186eee6f43cc407ca6079f1bf9d \
	--control-plane --certificate-key a9fef33e0b267f3cf4649dc359cd533afe8c494c29dd3362af64bf844d0a8ca7 \
--apiserver-advertise-address 10.0.0.153 

# Worker nodes
kubeadm join 10.0.0.150:6443 --token 1blku5.lgijw9i3fprtty40 \
--discovery-token-ca-cert-hash sha256:46b87971b06d9f09e85487b3b4ba4723c1eec186eee6f43cc407ca6079f1bf9d
```