## Pre-requisites: 
- Install `kops`  
- AWS programmatic access for kops user 
- S3 bucket for Terraform backend
- Domain name for K8S cluster 

### 1. Install kops 
    Refer https://kubernetes.io/docs/setup/production-environment/tools/kops/ 

### 2. Create Route53 subdomain 
    - Create sub domain and create NS records in parent domain
    ```
    $ aws route53 create-hosted-zone --name cluster1.cetdevops.com --caller-reference 1
    ```
    Verify if domain has been setup corectly. 
    You should see the 4 NS records that Route53 assigned your hosted zone
    ```$ dig NS cluster1.cetdevops.com```

 ### 3. Create S3 bucket
    - Export AWS_PROFILE
    - Create the S3 bucket using 
        ```aws s3 mb s3://clusters.cetdevops.com```
    - Export KOPS_STATE_STORE=s3://clusters.cetdevops.com
    
### 4. Build cluster configuration    
    ```$ kops create cluster --zones=us-east-1a useast1.cluster1.cetdevops.com```
    
    - kops will create the configuration for your cluster. Note that it only creates the configuration, it does not actually create the cloud resources - you’ll do that in the next step with a kops update cluster. 
    This give you an opportunity to review the configuration or change it.
    It prints commands you can use to explore further:

    * List your clusters with: kops get cluster
    * Edit this cluster with: kops edit cluster useast1.cluster1.cetdevops.com
    * Edit your node instance group: kops edit ig --name=useast1.cluster1.cetdevops.com nodes
    * Edit your master instance group: kops edit ig --name=useast1.cluster1.cetdevops.com master-us-east-1a
    
### 5. Create AWS cluster in AWS
   
   Run “kops update cluster” to create your cluster in AWS:
   
   ```kops update cluster useast1.cluster1.cetdevops.com --yes```
   
   That takes a few seconds to run, but then your cluster will likely take a few minutes to actually be ready. 
   kops update cluster will be the tool you’ll use whenever you change the configuration of your cluster; 
   it applies the changes you have made to the configuration to your cluster - reconfiguring AWS or kubernetes as needed.
   
   For example, after you kops edit ig nodes, then kops update cluster --yes to apply your configuration, 
   and sometimes you will also have to kops rolling-update cluster to roll out the configuration immediately.   
   
   For example, after you kops edit ig nodes, then kops update cluster --yes to apply your configuration, and sometimes 
   you will also have to kops rolling-update cluster to roll out the configuration immediately
   
### 6. Cleanup

   To delete your cluster: 
   
   ```kops delete cluster useast1.cluster1.cetdevops.com --yes```
   
7. Addons
    ```https://kubernetes.io/docs/concepts/cluster-administration/addons/```   


## References: 
- https://github.com/kubernetes/kops    
