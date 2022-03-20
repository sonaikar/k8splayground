# Minikube for Kubernetes Playground
minikube is local Kubernetes, focusing on making it easy to learn and develop for
Kubernetes. 

All you need is Docker (or similarly compatible) container or a Virtual Machine
environment, and Kubernetes is a single command away: minikube start

## What you will need :

* 2 CPUs or more
* 2GB of free memory
* 20GB of free disk space
* Internet connection
* Container or virtual machine manager, such as: Docker, Hyperkit, Hyper-V,
KVM, Parallels, Podman, VirtualBox, or VMware Fusion/Workstation

## Before you begin
You must use a kubectl version that is within one minor version difference of your
cluster. For example, a v1.23 client can communicate with v1.22, v1.23, and v1.24
control planes. Using the latest compatible version of kubectl helps avoid unforeseen
issues.

### Install kubectl on Linux
Download the latest release with the command:
```bash
$ curl -LO "https://dl.k8s.io/release/$(curl -L -s
https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Validate the binary (optional)
# Download the kubectl checksum file:
$ curl -LO "https://dl.k8s.io/$(curl -L -s
https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

# Validate the kubectl binary against the checksum file:
$ echo "$(<kubectl.sha256) kubectl" | sha256sum --check
# If valid, the output is:
# kubectl: OK
```

### Install kubectl
```bash
$ sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
# If you do not have root access on the target system, you can still install kubectl to the
~/.local/bin directory:
$ chmod +x kubectl
$ mkdir -p ~/.local/bin/kubectl
$ mv ./kubectl ~/.local/bin/kubectl
# and then append (or prepend) ~/.local/bin to $PATH
# Test to ensure the version you installed is up-to-date:
$ kubectl version --client
```

### Minikube Installation:
If you are using Linux OS other than ubuntu 20.04 please visit the following URL for
installation steps:
```bash
# Document; https://minikube.sigs.k8s.io/docs/start/
# To install the latest minikube stable release on x86-64 Linux using binary download:
$ curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
$ sudo install minikube-linux-amd64 /usr/local/bin/minikube
# Start your cluster
$ minikube start
# Wait for 5-10 min to start your Kubernetes cluster. The output should be similar to the following
```

![img.png](img.png)