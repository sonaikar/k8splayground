### Reference:  https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster
### Reference: https://shahbhargav.medium.com/kubernetes-cluster-backup-and-restore-using-etcdctl-tool-35831702ab7e

# Download etcdctl on master
```bash
#!/bin/bash

ETCD_VERSION=${ETCD_VERSION:-v3.3.1}

curl -L https://github.com/coreos/etcd/releases/download/$ETCD_VERSION/etcd-$ETCD_VERSION-linux-amd64.tar.gz -o etcd-$ETCD_VERSION-linux-amd64.tar.gz

tar xzvf etcd-$ETCD_VERSION-linux-amd64.tar.gz
rm etcd-$ETCD_VERSION-linux-amd64.tar.gz

cd etcd-$ETCD_VERSION-linux-amd64
sudo cp etcd /usr/local/bin/
sudo cp etcdctl /usr/local/bin/

rm -rf etcd-$ETCD_VERSION-linux-amd64

etcdctl --version
```


#Create workload for testing backup
```bash
kubectl create namespace test
kubectl config set-context $(kubectl config current-context) --namespace test
kubectl create deployment web --image=nginx:1.17
kubectl scale deployment web --replicas=3
kubectl expose deploy web --port=80 --target-port=80 --type=NodePort
```

### Change context
```bash
kubectl config set-context $(kubectl config current-context) --namespace kube-system
```

### etcd backup command format
ETCDCTL_API=3 etcdctl snapshot save <backup-file-location> \
--endpoints=https://127.0.0.1:2379 \
--cacert=<trusted-ca-file> \
--cert=<cert-file> \
--key=<key-file>


=================================================================
# You can find required information from etcd.yaml or simple get etcd pod

```bash
apt install jq 
kubectl get pods etcd-k8smaster -n kube-system \
-o=jsonpath='{.spec.containers[0].command}' | jq
```
=================================================================
#so the command will be
```bash
ETCDCTL_API=3 etcdctl \
--endpoints=https://10.0.0.111:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key \
snapshot save /root/snapshot-backup.db



# We can verify by the command
ETCDCTL_API=3 \
  etcdctl --endpoints=https://10.0.0.111:2379  \
  --write-out=table snapshot status /root/snapshot-backup.db
```

# Let's delete the deployment and namespace
```bash
kubectl delete ns test
```

# Restore etcd
```bash
ETCDCTL_API=3 etcdctl \
--endpoints=https://10.0.0.111:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--name=k8smaster \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key \
--data-dir=/var/lib/etcd-from-backup \
--initial-cluster=k8smaster=https://10.0.0.111:2380 \
--initial-cluster-token=etcd-cluster-new \
--initial-advertise-peer-urls=https://10.0.0.111:2380 \
snapshot restore /root/snapshot-backup.db
```

### Modify etcd.yaml file 

--data-dir=/var/lib/etcd-from-backup
--initial-cluster-token=etcd-cluster-new

volumeMounts:
    - mountPath: /var/lib/etcd-from-backup
      name: etcd-data
    - mountPath: /etc/kubernetes/pki/etcd
      name: etcd-certs
  hostNetwork: true
  priorityClassName: system-cluster-critical
  volumes:
  - hostPath:
      path: /var/lib/etcd-from-backup
      type: DirectoryOrCreate
    name: etcd-data
  - hostPath:
      path: /etc/kubernetes/pki/etcd
      type: DirectoryOrCreate
    name: etcd-certs
    

