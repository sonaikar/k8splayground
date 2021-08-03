#### KOPS: Create kubernetes cluster setup 
export NAME=$(terraform output name)
export KOPS_STATE_STORE=$(terraform output state_store)
#export ZONES=$(terraform output -json availability_zones | jq -r '.value|join(",")')
export ZONES="us-east-1a,us-east-1b,us-east-1c"
export DNS_ZONE_ID=$(terraform output public_zone_id)
export VPC_ID=$(terraform output vpc_id)
#export VPC_CIDR=$(terraform output vpc_cidr)
export VPC_CIDR="10.30.0.0/16"
# export SUBNET_IDS="$(terraform output private_subnet_ids)"
# export SUBNET_IDS=$(echo $SUBNET_IDS | sed 's/\s//g')
# echo $SUBNET_IDS
# export UTILITY_SUBNET_IDS="$(terraform output public_subnet_ids)"
# export UTILITY_SUBNET_IDS=$(echo $UTILITY_SUBNET_IDS | sed 's/\s//g')
# export UTILITY_SUBNET_IDS=$(echo $UTILITY_SUBNET_IDS | sed 's/\s//g')
# echo $
export ENVNAME=prod
export KUBERNETES_VERSION=1.10.6
export TORHQ_NW="207.167.242.200/29"


kops create cluster \
  --cloud=aws \
  --topology=private \
  --vpc=$VPC_ID \
  --network-cidr=$VPC_CIDR \
  --master-zones=$ZONES \
  --zones=$ZONES \
  --dns-zone=$DNS_ZONE_ID \
  --node-count=3 \
  --node-size=c5.4xlarge \
  --master-size=m5.2xlarge \
  --ssh-public-key ${SSH_PUBLIC_KEY:-~/.ssh/kopsprod.pub} \
  --networking=calico \
  --dns=private \
  --cloud-labels="AssetName=k8s,Environment=${ENVNAME},kubernetes.io/cluster/${NAME}=owned" \
  --authorization RBAC \
  --associate-public-ip=true \
  --admin-access=${TORHQ_NW} \
  --ssh-access=${TORHQ_NW} \
  --kubernetes-version=${KUBERNETES_VERSION} \
  --state=${KOPS_STATE_STORE} \
  --target "terraform"  \
  --name="$NAME"
