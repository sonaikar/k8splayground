# -*- mode: ruby -*-
# vi: set ft=ruby :

# Cluster configuration
MASTERS = 3
WORKERS = 1
MASTER_IP_START = "10.0.0.110"
WORKER_IP_START = "10.0.0.120"
LB_IP = "10.0.0.100"

Vagrant.configure("2") do |config|
  # Use Fedora 43 from custom URL
  config.vm.box = "fedora/43"
  config.vm.box_url = "https://muug.ca/mirror/fedora/linux/releases/43/Cloud/x86_64/images/Fedora-Cloud-Base-Vagrant-libvirt-43-1.6.x86_64.vagrant.libvirt.box"
  config.vm.box_check_update = true

  # Shared folder
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"

  # Load Balancer for HA Masters
  config.vm.define "k8s-lb" do |lb|
    lb.vm.hostname = "k8s-lb"
    lb.vm.network "private_network", ip: LB_IP

    lb.vm.provider "virtualbox" do |vb|
      vb.name = "k8s-lb"
      vb.memory = "1024"
      vb.cpus = 1
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    end

    # Port forwarding for Kubernetes API server through load balancer
    lb.vm.network "forwarded_port", guest: 6443, host: 6443, auto_correct: true
    lb.vm.network "forwarded_port", guest: 80, host: 8080, auto_correct: true

    lb.vm.provision "shell", inline: <<-SHELL
      dnf update -y
      dnf install -y haproxy

      # Configure HAProxy for Kubernetes API server load balancing
      cat <<EOF > /etc/haproxy/haproxy.cfg
global
    daemon
    log stdout local0

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    log global

frontend k8s-api
    bind *:6443
    mode tcp
    default_backend k8s-masters

backend k8s-masters
    mode tcp
    balance roundrobin
    server master1 #{MASTER_IP_START.gsub(/\d+$/, '110')}:6443 check
    server master2 #{MASTER_IP_START.gsub(/\d+$/, '111')}:6443 check
    server master3 #{MASTER_IP_START.gsub(/\d+$/, '112')}:6443 check
EOF

      systemctl enable haproxy
      systemctl start haproxy
    SHELL
  end

  # Master nodes
  (1..MASTERS).each do |i|
    config.vm.define "k8s-master#{i}" do |master|
      master.vm.hostname = "k8s-master#{i}"
      master_ip = MASTER_IP_START.gsub(/\d+$/, (109 + i).to_s)
      master.vm.network "private_network", ip: master_ip

      master.vm.provider "virtualbox" do |vb|
        vb.name = "k8s-master#{i}"
        vb.memory = "4096"  # 4GB RAM for masters
        vb.cpus = 2
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      end

      # Master-specific provisioning
      master.vm.provision "shell", inline: <<-SHELL
        echo "=== Configuring Master Node #{i} ==="
        echo "#{master_ip} k8s-master#{i}" >> /etc/hosts
        echo "#{LB_IP} k8s-lb" >> /etc/hosts
      SHELL
    end
  end

  # Worker nodes
  (1..WORKERS).each do |i|
    config.vm.define "k8s-worker#{i}" do |worker|
      worker.vm.hostname = "k8s-worker#{i}"
      worker_ip = WORKER_IP_START.gsub(/\d+$/, (119 + i).to_s)
      worker.vm.network "private_network", ip: worker_ip

      worker.vm.provider "virtualbox" do |vb|
        vb.name = "k8s-worker#{i}"
        vb.memory = "2048"  # 2GB RAM for workers
        vb.cpus = 2
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      end

      # Port forwarding for NodePort services (only on workers)
      worker.vm.network "forwarded_port", guest: 30000, host: 30000, auto_correct: true
      worker.vm.network "forwarded_port", guest: 30001, host: 30001, auto_correct: true

      # Worker-specific provisioning
      worker.vm.provision "shell", inline: <<-SHELL
        echo "=== Configuring Worker Node #{i} ==="
        echo "#{worker_ip} k8s-worker#{i}" >> /etc/hosts
        echo "#{LB_IP} k8s-lb" >> /etc/hosts
      SHELL
    end
  end

  # Common provisioning script for all nodes
  config.vm.provision "shell", inline: <<-SHELL
    set -e

    echo "=== Updating system packages ==="
    dnf update -y

    echo "=== Installing required packages ==="
    dnf install -y \
      curl \
      wget \
      git \
      vim \
      htop \
      net-tools \
      bridge-utils \
      iptables \
      tc \
      socat \
      conntrack \
      ipset

    echo "=== Configuring system settings for Kubernetes ==="

    # Disable swap (required for Kubernetes)
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # Load required kernel modules
    cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

    modprobe overlay
    modprobe br_netfilter

    # Configure sysctl parameters for Kubernetes
    cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

    sysctl --system

    echo "=== Installing containerd container runtime ==="

    # Install containerd
    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    dnf install -y containerd.io

    # Configure containerd
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml

    # Configure containerd to use systemd cgroup driver
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

    # Enable and start containerd
    systemctl enable containerd
    systemctl start containerd

    echo "=== Installing Kubernetes components ==="

    # Add Kubernetes repository
    cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

    # Install Kubernetes components
    dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

    # Enable kubelet service
    systemctl enable kubelet

    echo "=== Configuring firewall ==="

    # Configure firewall for Kubernetes
    systemctl enable firewalld
    systemctl start firewalld

    # Open required ports for Kubernetes master node
    firewall-cmd --permanent --add-port=6443/tcp     # Kubernetes API server
    firewall-cmd --permanent --add-port=2379-2380/tcp # etcd server client API
    firewall-cmd --permanent --add-port=10250/tcp    # Kubelet API
    firewall-cmd --permanent --add-port=10259/tcp    # kube-scheduler
    firewall-cmd --permanent --add-port=10257/tcp    # kube-controller-manager
    firewall-cmd --permanent --add-port=30000-32767/tcp # NodePort Services

    # Open ports for worker nodes (if this will be used as worker)
    firewall-cmd --permanent --add-port=10250/tcp    # Kubelet API
    firewall-cmd --permanent --add-port=30000-32767/tcp # NodePort Services

    # Reload firewall rules
    firewall-cmd --reload

    echo "=== Disabling SELinux (temporary for Kubernetes compatibility) ==="
    setenforce 0
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

    echo "=== Creating helpful aliases and environment ==="

    # Add kubectl completion and aliases for vagrant user
    echo 'source <(kubectl completion bash)' >> /home/vagrant/.bashrc
    echo 'alias k=kubectl' >> /home/vagrant/.bashrc
    echo 'complete -F __start_kubectl k' >> /home/vagrant/.bashrc

    # Add useful environment variables
    echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /home/vagrant/.bashrc

    echo "=== Adding all cluster nodes to /etc/hosts ==="

    # Add all cluster nodes to hosts file
    echo "#{LB_IP} k8s-lb" >> /etc/hosts
    echo "#{MASTER_IP_START.gsub(/\d+$/, '110')} k8s-master1" >> /etc/hosts
    echo "#{MASTER_IP_START.gsub(/\d+$/, '111')} k8s-master2" >> /etc/hosts
    echo "#{MASTER_IP_START.gsub(/\d+$/, '112')} k8s-master3" >> /etc/hosts
    echo "#{WORKER_IP_START.gsub(/\d+$/, '120')} k8s-worker1" >> /etc/hosts

    echo "=== Creating cluster initialization scripts ==="

    # Create script to initialize the first master
#    cat <<'INIT_FIRST_MASTER' > /home/vagrant/init-first-master.sh
##!/bin/bash
#
#echo "Initializing first master node..."
#
## Initialize the cluster with HA configuration
#sudo kubeadm init \
#  --control-plane-endpoint="k8s-lb:6443" \
#  --upload-certs \
#  --apiserver-advertise-address=$(hostname -I | awk '{print $2}') \
#  --pod-network-cidr=10.244.0.0/16
#
## Set up kubectl for vagrant user
#mkdir -p /home/vagrant/.kube
#sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
#sudo chown vagrant:vagrant /home/vagrant/.kube/config
#
## Install Flannel CNI plugin
#kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
#
#echo "First master initialized successfully!"
#echo "Save the join commands displayed above to join other masters and workers."
#INIT_FIRST_MASTER
#
#    # Create script to join additional masters
#    cat <<'JOIN_MASTER' > /home/vagrant/join-master.sh
##!/bin/bash
#
#echo "Use this script template to join additional master nodes:"
#echo "Replace TOKEN, HASH, and CERT_KEY with values from first master init output"
#echo ""
#echo "sudo kubeadm join k8s-lb:6443 \\"
#echo "  --token <TOKEN> \\"
#echo "  --discovery-token-ca-cert-hash sha256:<HASH> \\"
#echo "  --control-plane \\"
#echo "  --certificate-key <CERT_KEY> \\"
#echo "  --apiserver-advertise-address=\$(hostname -I | awk '{print \$2}')"
#echo ""
#echo "After joining, set up kubectl:"
#echo "mkdir -p /home/vagrant/.kube"
#echo "sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config"
#echo "sudo chown vagrant:vagrant /home/vagrant/.kube/config"
#JOIN_MASTER
#
#    # Create script to join worker nodes
#    cat <<'JOIN_WORKER' > /home/vagrant/join-worker.sh
##!/bin/bash
#
#echo "Use this script template to join worker nodes:"
#echo "Replace TOKEN and HASH with values from first master init output"
#echo ""
#echo "sudo kubeadm join k8s-lb:6443 \\"
#echo "  --token <TOKEN> \\"
#echo "  --discovery-token-ca-cert-hash sha256:<HASH>"
#JOIN_WORKER
#
#    chmod +x /home/vagrant/init-first-master.sh
#    chmod +x /home/vagrant/join-master.sh
#    chmod +x /home/vagrant/join-worker.sh
#    chown vagrant:vagrant /home/vagrant/init-first-master.sh
#    chown vagrant:vagrant /home/vagrant/join-master.sh
#    chown vagrant:vagrant /home/vagrant/join-worker.sh
#
#    echo "=== Setup complete! ==="
#    echo ""
#    echo "Multi-node Kubernetes cluster setup:"
#    echo "1. SSH to k8s-master1: vagrant ssh k8s-master1"
#    echo "2. Initialize cluster: ./init-first-master.sh"
#    echo "3. Use join commands from output to join other nodes"
#    echo "4. Check cluster: kubectl get nodes"
#    echo ""

  SHELL
end
