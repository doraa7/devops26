##############
# Upgrade jx #
##############

jx version

####################
# Create a cluster #
####################

export AWS_ACCESS_KEY_ID=[...] # Replace [...] with the AWS Access Key ID

export AWS_SECRET_ACCESS_KEY=[...] # Replace [...] with the AWS Secret Access Key

export AWS_DEFAULT_REGION=us-west-2

jx create cluster eks \
    --cluster-name jx-rocks \
    --region $AWS_DEFAULT_REGION \
    --node-type t2.large \
    --nodes 3 \
    --nodes-min 3 \
    --nodes-max 6 \
    --skip-installation \
    --batch-mode

#############################
# Create Cluster Autoscaler #
#############################

ASG_NAME=$(aws autoscaling \
    describe-auto-scaling-groups \
    | jq -r ".AutoScalingGroups[] \
    | select(.AutoScalingGroupName \
    | startswith(\"eksctl-jx-rocks-nodegroup\")) \
    .AutoScalingGroupName")

echo $ASG_NAME

aws autoscaling \
    create-or-update-tags \
    --tags \
    ResourceId=$ASG_NAME,ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/enabled,Value=true,PropagateAtLaunch=true \
    ResourceId=$ASG_NAME,ResourceType=auto-scaling-group,Key=kubernetes.io/cluster/jx-rocks,Value=true,PropagateAtLaunch=true

IAM_ROLE=$(aws iam list-roles \
    | jq -r ".Roles[] \
    | select(.RoleName \
    | startswith(\"eksctl-jx-rocks-nodegroup\")) \
    .RoleName")

echo $IAM_ROLE

aws iam put-role-policy \
    --role-name $IAM_ROLE \
    --policy-name jx-rocks-AutoScaling \
    --policy-document https://raw.githubusercontent.com/vfarcic/k8s-specs/master/scaling/eks-autoscaling-policy.json

mkdir -p charts

helm fetch stable/cluster-autoscaler \
    -d charts \
    --untar

mkdir -p k8s-specs/aws

helm template charts/cluster-autoscaler \
    --name aws-cluster-autoscaler \
    --output-dir k8s-specs/aws \
    --namespace kube-system \
    --set autoDiscovery.clusterName=jx-rocks \
    --set awsRegion=us-west-2 \
    --set sslCertPath=/etc/kubernetes/pki/ca.crt \
    --set rbac.create=true

kubectl apply \
    -n kube-system \
    -f k8s-specs/aws/cluster-autoscaler/*

#######################
# Destroy the cluster #
#######################

# Only if there are no other ELBs in that region. Otherwise, remove the LB manually.
LB_ARN=$(aws elbv2 describe-load-balancers | jq -r \
    ".LoadBalancers[0].LoadBalancerArn")

echo $LB_ARN

aws elbv2 delete-load-balancer \
    --load-balancer-arn $LB_ARN

IAM_ROLE=$(aws iam list-roles \
    | jq -r ".Roles[] \
    | select(.RoleName \
    | startswith(\"eksctl-jx-rocks-nodegroup\")) \
    .RoleName")

echo $IAM_ROLE

aws iam delete-role-policy \
    --role-name $IAM_ROLE \
    --policy-name jx-rocks-AutoScaling

eksctl delete cluster -n jx-rocks

# Delete unused volumes
for volume in `aws ec2 describe-volumes --output text| grep available | awk '{print $8}'`; do 
    echo "Deleting volume $volume"
    aws ec2 delete-volume --volume-id $volume
done