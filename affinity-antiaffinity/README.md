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
        