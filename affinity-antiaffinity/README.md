References: 
https://kubernetes.io/blog/2017/03/advanced-scheduling-in-kubernetes/
https://kubernetes.io/docs/reference/labels-annotations-taints/
https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/


## Assigning Pods to Nodes
You can constrain a Pod so that it can only run on particular set of Node(s). There are several ways to do this and the recommended approaches all use label selectors to facilitate the selection. Generally such constraints are unnecessary, as the scheduler will automatically do a reasonable placement (e.g. spread your pods across nodes so as not place the pod on a node with insufficient free resources, etc.) but there are some circumstances where you may want to control which node the pod deploys to - for example to ensure that a pod ends up on a machine with an SSD attached to it, or to co-locate pods from two different services that communicate a lot into the same availability zone.

##nodeSelector
nodeSelector is the simplest recommended form of node selection constraint. nodeSelector is a field of PodSpec. It specifies a map of key-value pairs. For the pod to be eligible to run on a node, the node must have each of the indicated key-value pairs as labels (it can have additional labels as well). The most common usage is one key-value pair.

## Attach label to the node

Run kubectl get nodes to get the names of your cluster's nodes. Pick out the one that you want to add a label to, and then run kubectl label nodes <node-name> <label-key>=<label-value> to add a label to the node you've chosen. For example, if my node name is 'kubernetes-foo-node-1.c.a-robinson.internal' and my desired label is 'disktype=ssd', then I can run kubectl label nodes kubernetes-foo-node-1.c.a-robinson.internal disktype=ssd.

You can verify that it worked by re-running kubectl get nodes --show-labels and checking that the node now has a label. You can also use kubectl describe node "nodename" to see the full list of labels of the given node.



requiredDuringSchedulingIgnoredDuringExecution: 

1. requiredDuringScheduling  - Mandatory 
2. IgnoredDuringExecution   - Ignored/Optional
 

preferredDuringSchedulingIgnoredDuringExecution: 

1. preferredDuringScheduling - optional 
2. IgnoredDuringExecution - optional


Node: 
    Label: 
      app: web
      
      
Inbuilt Node Labels:

beta.kubernetes.io/arch=amd64,
beta.kubernetes.io/instance-type=t2.medium,
beta.kubernetes.io/os=linux,
failure-domain.beta.kubernetes.io/region=us-east-1,
failure-domain.beta.kubernetes.io/zone=us-east-1a,
kops.k8s.io/instancegroup=nodes,
kubernetes.io/arch=amd64,
kubernetes.io/hostname=ip-172-20-36-66.ec2.internal,
kubernetes.io/os=linux,
kubernetes.io/role=node,
node-role.kubernetes.io/node=
        
