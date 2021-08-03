## Variables 
ENV=prod
BUCKET_ID=k8s${ENV}.fleetcomplete.co
#BUCKET_ID=k8s
ORG=k8s${ENV}.fleetcomplete.co; export ORG
KEY_NAME=kopsprod; export KEY_NAME
HOSTED_ZONE_ID=Z276FWWA51NIGU; export DNS_ZONE

## creds directory
mkdir -p creds

AWSPROFILE=prod; export AWSPROFILE 
export AWS_PROFILE=${AWSPROFILE}
echo "Set AWS Profile to ${AWS_PROFILE}"

## AWS configuration
aws iam create-group \
  --group-name kopsprod

aws iam attach-group-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess \
  --group-name kopsprod

aws iam attach-group-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess \
  --group-name kopsprod

aws iam attach-group-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess \
  --group-name kopsprod

aws iam attach-group-policy \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess \
  --group-name kopsprod

aws iam attach-group-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess \
  --group-name kopsprod

aws iam create-user \
  --user-name kopsprod

aws iam add-user-to-group \
  --user-name kopsprod \
  --group-name kopsprod

aws iam create-access-key \
  --user-name kopsprod >creds/kops-creds

echo "BUCKET ID = $BUCKET_ID"
sed -i 's/MY_BUCKET_ID/'$BUCKET_ID'/' ./kops.env
#sed -i .bak 's/MY_BUCKET_ID/'$BUCKET_ID'/' ./kops.env

echo "ORG NAME = $ORG"
sed -i 's/MY_ORG_NAME/'$ORG'/' ./kops.env
#sed -i .bak 's/MY_ORG_NAME/'$org'/' ./kops.env

echo "HOSTED ZONE ID = $HOSTED_ZONE_ID"
sed -i 's/MY_HOSTED_ZONE_ID/'$HOSTED_ZONE_ID'/' ./kops.env
#sed -i .bak 's/MY_ORG_NAME/'$org'/' ./kops.env
#echo "Enter your organization's name (lowercase): "
#read -r org

aws ec2 describe-key-pairs --query 'KeyPairs[].KeyName' |  grep -q ${KEY_NAME} 

if [ $? -ne "0" ]; then
  # Create key pair for EC2 instances
  aws ec2 create-key-pair \
    --key-name ${KEY_NAME}  \
    | jq -r '.KeyMaterial' \
    > ~/.ssh/${KEY_NAME}.pem

  chmod 400 ~/.ssh/${KEY_NAME}.pem

  ssh-keygen -y -f ~/.ssh/${KEY_NAME}.pem > ~/.ssh/${KEY_NAME}.pub
fi


### Terraform script to setup environment 
#terraform plan 


