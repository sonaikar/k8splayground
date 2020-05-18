###########################################################################################################
# Create IAM User
aws iam create-group --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name kops
aws iam create-user --user-name kops
aws iam add-user-to-group --user-name kops --group-name kops
aws iam create-access-key --user-name kops

###########################################################################################################
#  Setup AWS credentials
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)

###########################################################################################################
# Create Subdomain
ID=$(uuidgen) && aws route53 create-hosted-zone --name kcluster.cetdevops.com --caller-reference $ID | \
jq .DelegationSet.NameServers

# Note parent id
aws route53 list-hosted-zones | jq '.HostedZones[] | select(.Name=="cetdevops.com.") | .Id'

# Create json with values received from subdomain
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

# Apply to Route 53
aws route53 change-resource-record-sets \
 --hosted-zone-id Z21857AYYZAKB2 \
 --change-batch file://subdomain.json

# Check DNS entry has been populated
dig ns kcluster.cetdevops.com

###########################################################################################################
# Create S3 storage
aws s3api create-bucket \
    --bucket kcluster-cetdevops-com-state-store \
    --region us-east-1

# Enable bucket versioning
aws s3api put-bucket-versioning --bucket kcluster-cetdevops-com-state-store  --versioning-configuration Status=Enabled

###########################################################################################################
# find aws image to use https://github.com/kubernetes/kops/blob/master/docs/operations/images.md
aws ec2 describe-images --region us-east-1 --output table \
  --owners 099720109477 \
  --query "sort_by(Images, &CreationDate)[*].[CreationDate,Name,ImageId]" \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-*"

###########################################################################################################
# Expose cluster details
export NAME=kcluster.cetdevops.com
export KOPS_STATE_STORE=s3://kcluster-cetdevops-com-state-store

# Create cluster configuration
kops create cluster \
    --node-count 3 \
    --master-count 3 \
    --zones us-east-1a,us-east-1b,us-east-1c \
    --master-zones us-east-1a,us-east-1b,us-east-1c  \
    --dns-zone Z0152517T0FAIUKH6N2U \
    --node-size t2.medium \
    --master-size t2.medium \
    --topology private \
    --networking calico \
    --cloud-labels "Team=DevOps,Owner=Sameer Sonaikar" \
    --image "ami-05801d0a3c8e4c443" \
    --state "s3://kcluster-cetdevops-com-state-store" \
    --bastion \
    ${NAME}


    --target terraform \
    --out . \
#
Suggestions:
 * list clusters with: kops get cluster
 * edit this cluster with: kops edit cluster kcluster.cetdevops.com
 * edit your node instance group: kops edit ig --name=kcluster.cetdevops.com nodes
 * edit your master instance group: kops edit ig --name=kcluster.cetdevops.com master-us-east-1a

Finally configure your cluster with: kops update cluster --name kcluster.cetdevops.com --yes


# Our cluster will be using only private IPs and external access will be only via the load balancer, hence our topology will be private.
# Networking CNI can be, calico, , flannel, kubernetes-native,

# Create ssh key
kops create secret --name ${NAME} sshpublickey admin -i ~/.ssh/id_rsa.pub
