### Voluntary and involuntary disruptions

Pods do not disappear until someone (a person or a controller) destroys them, or there is an unavoidable hardware or system software error.

We call these unavoidable cases involuntary disruptions to an application. Examples are:

a hardware failure of the physical machine backing the node
cluster administrator deletes VM (instance) by mistake
cloud provider or hypervisor failure makes VM disappear
a kernel panic
the node disappears from the cluster due to cluster network partition
eviction of a pod due to the node being out-of-resources.

# References: 
https://kubernetes.io/docs/concepts/workloads/pods/disruptions/
https://kubernetes.io/docs/tasks/run-application/configure-pdb/