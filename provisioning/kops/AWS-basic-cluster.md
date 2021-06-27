# Setup AWS 

### Setup IAM User

In order to build clusters within AWS we'll create a dedicated IAM user for kops. This user requires API credentials in order to use kops. Create the user, and credentials, using the AWS console.

The kops user will require the following IAM permissions to function properly:
```.env
AmazonEC2FullAccess
AmazonRoute53FullAccess
AmazonS3FullAccess
IAMFullAccess
AmazonVPCFullAccess 
```
   
You can create the kops IAM user from the command line using the following:

```shell script
aws iam create-group --group-name kops

aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name kops

aws iam create-user --user-name kops

aws iam add-user-to-group --user-name kops --group-name kops

aws iam create-access-key --user-name kops
```

You should record the SecretAccessKey and AccessKeyID in the returned JSON output, and then use them below:

```shell script
# configure the aws client to use your new IAM user
aws configure           # Use your new access and secret key here
aws iam list-users      # you should see a list of all your IAM users here

# Because "aws configure" doesn't export these vars for kops to use, we export them now
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
```

## Configure DNS

#### Scenario 1a: A Domain purchased/hosted via AWS
If you bought your domain with AWS, then you should already have a hosted zone in Route53. If you plan to use this domain then no more work is needed.

In this example you own example.com and your records for Kubernetes would look like etcd-us-east-1c.internal.clustername.example.com

#### Scenario 1b: A subdomain under a domain purchased/hosted via AWS
In this scenario you want to contain all kubernetes records under a subdomain of a domain you host in Route53. This requires creating a second hosted zone in route53, and then setting up route delegation to the new zone.

- Create the subdomain, and note your SUBDOMAIN name servers
    ```shell script
    # Note: This example assumes you have jq installed locally.
    ID=$(uuidgen) && aws route53 create-hosted-zone --name kcluster.cetdevops.com --caller-reference $ID | \
    jq .DelegationSet.NameServers
    ```
- Note your PARENT hosted zone id
    ```shell script
    # Note: This example assumes you have jq installed locally.
    aws route53 list-hosted-zones | jq '.HostedZones[] | select(.Name=="cetdevops.com.") | .Id'
    ```
- Create a new JSON file with your values (subdomain.json)
    ```json
{
  "Comment": "Create a subdomain NS record in the parent domain",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "kcluster.cetdevops.com",
        "Type": "NS",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "ns-922.awsdns-51.net"
          },
          {
            "Value": "ns-1489.awsdns-58.org"
          },
          {
            "Value": "ns-300.awsdns-37.com"
          },
          {
            "Value": "ns-1648.awsdns-14.co.uk"
          }
        ]
      }
    }
  ]
}
    ```
- Apply the SUBDOMAIN NS records to the PARENT hosted zone.

```json
aws route53 change-resource-record-sets \
 --hosted-zone-id Z21857AYYZAKB2 \
 --change-batch file://subdomain.json
```

#### Testing your DNS setup
You should now be able to dig your domain (or subdomain) and see the AWS Name Servers on the other end.

```shell script
dig ns kcluster.cetdevops.com
```  
This is a critical component when setting up clusters. 
If you are experiencing problems with the Kubernetes API not coming up, chances are something is wrong with the cluster's DNS.

#### Please DO NOT MOVE ON until you have validated your NS records! This is not required if a gossip-based cluster is created.

## Cluster State storage
In order to store the state of your cluster, and the representation of your cluster, we need to create a dedicated S3 bucket for kops to use. This bucket will become the source of truth for our cluster configuration

We recommend keeping the creation of this bucket confined to us-east-1, otherwise more work will be required.

```shell script
aws s3api create-bucket \
    --bucket kcluster-cetdevops-com-state-store \
    --region us-east-1
```

#### Note: We STRONGLY recommend versioning your S3 bucket in case you ever need to revert or recover a previous state store.    

```shell script
aws s3api put-bucket-versioning --bucket kcluster-cetdevops-com-state-store  --versioning-configuration Status=Enabled
```

## Creating your first cluster
We're ready to start creating our first cluster! Let's first set up a few environment variables to make the process easier.

```shell script
export NAME=kcluster.cetdevops.com
export KOPS_STATE_STORE=s3://kcluster-cetdevops-com-state-store
```

### Create cluster configuration
We will need to note which availability zones are available to us. In this example we will be deploying our cluster to the us-eas-1 region

```shell script
    aws ec2 describe-availability-zones --region us-east-1
```

Below is a create cluster command. We'll use the most basic example possible, with more verbose examples in high availability. The below command will generate a cluster configuration, but will not start building it. Make sure you have generated an SSH key pair before creating your cluster.

```shell script
kops create cluster \
    --zones=us-east-1a \
    ${NAME}
```

### Customize Cluster Configuration
Now we have a cluster configuration, we can look at every aspect that defines our cluster by editing the description.

```shell script
kops edit cluster ${NAME}
```

This opens your editor (as defined by $EDITOR) and allows you to edit the configuration. The configuration is loaded from the S3 bucket we created earlier, and automatically updated when we save and exit the editor.

### Build the Cluster
Now we take the final step of actually building the cluster. This'll take a while. Once it finishes you'll have to wait longer while the booted instances finish downloading Kubernetes components and reach a "ready" state.
```kops update cluster ${NAME} --yes```

### Use the Cluster
Remember when you installed kubectl earlier? The configuration for your cluster was automatically generated and written to ~/.kube/config for you!

A simple Kubernetes API call can be used to check if the API is online and listening. Let's use kubectl to check the nodes.

```shell script
kubectl get nodes
```

You will see a list of nodes that should match the --zones flag defined earlier. This is a great sign that your Kubernetes cluster is online and working.

kops also ships with a handy validation tool that can be ran to ensure your cluster is working as expected.

```shell script
kops validate cluster
```

You can look at all system components with the following command.

```shell script
kubectl -n kube-system get po
```

## Delete the Cluster

Running a Kubernetes cluster within AWS obviously costs money, and so you may want to delete your cluster if you are finished running experiments.

You can preview all of the AWS resources that will be destroyed when the cluster is deleted by issuing the following command

```shell script
kops delete cluster --name ${NAME}
```

When you are sure you want to delete your cluster, issue the delete command with the --yes flag. Note that this command is very destructive, and will delete your cluster and everything contained within it!

```shell script
kops delete cluster --name ${NAME} --yes
```
