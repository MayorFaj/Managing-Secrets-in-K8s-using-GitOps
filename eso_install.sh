#!/bin/bash
set -e
: '
The following script has two functions with different actions
Install function installs the required Helm Chart
for the External Secrets Operator
on the Kubernetes cluster.

Permissions function creates required IRSA config
and configures required IAM Permissions for the 
ESO and connects that to the
service account.
'

echo "===================================================="
echo "Creating required Environment Variables."
echo "===================================================="

declare AWS_REGION="eu-central-1"
declare EKS_CLUSTER_NAME="rias-touch-cluster"
declare NAMESPACE="external-secrets"

install_eso(){

  echo "===================================================="
  echo "Installing the ESO Helm Chart."
  echo "===================================================="

  helm repo add external-secrets https://charts.external-secrets.io

  helm install external-secrets \
   external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --set installCRDs=true
}

#####################################################################################################################
#####################################################################################################################

permissions_eso(){

  echo "===================================================="
  echo "Creating IRSA for EKS Cluster"
  echo "===================================================="

  ###########################################################
  # You can skip this step if you have already configured   #
  # IRSA for your Kubernetes Cluster.                       #
  ###########################################################
  
  eksctl utils associate-iam-oidc-provider --cluster ${EKS_CLUSTER_NAME} --region ${AWS_REGION} --approve

  echo "===================================================="
  echo "Creating Service Account"
  echo "===================================================="

  # Setting the required parameters for OIDC Provider.
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
  OIDC_PROVIDER=$(aws eks describe-cluster --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION} --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

  ESO_SA_NAME="external-secrets-operator-sa"

  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${ESO_SA_NAME}
  namespace: ${NAMESPACE}
EOF

  echo "===================================================="
  echo "Creating Required IAM Role and Policy"
  echo "===================================================="

  # Creating IAM Trust Policy. 
  cat > trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:${NAMESPACE}:${ESO_K8S_SERVICE_ACCOUNT_NAME}"
        }
      }
    }
  ]
}
EOF
  
  # Setting the required Environment Variables for IRSA (IAM Roles for Service Accounts).
  ESO_IAM_ROLE="eso-iam-role"
  ESO_IAM_ROLE_DESCRIPTION='IRSA role for External Secrets Operator deployment on EKS cluster using Helm charts'

  aws iam create-role --role-name "${ESO_IAM_ROLE}" --assume-role-policy-document file://trust.json --description "${ESO_IAM_ROLE_DESCRIPTION}"

  ESO_IAM_ROLE_ARN=$(aws iam get-role --role-name=${ESO_IAM_ROLE} --query Role.Arn --output text)


  cat > policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateAlias",
        "kms:DeleteAlias",
        "kms:GenerateRandom",
        "kms:Decrypt",
        "kms:Describe*",
        "kms:Get*",
        "kms:List*",
        "kms:TagResource",
        "kms:UntagResource",

        "kms:CreateKey"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:DeleteParameter",
        "ssm:GetParameterHistory",
        "ssm:GetParametersByPath",
        "ssm:GetParameters",
        "ssm:GetParameter",
        "ssm:DeleteParameters",
        "ssm:DescribeParameters"
      ],
      "Resource": "*" 
    }
  ]
}
EOF
  
  ESO_IAM_POLICY="eso_secrets_manager_policy"
  aws iam create-policy --policy-name "${ESO_IAM_POLICY}" --policy-document file://policy.json 

  POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${ESO_IAM_POLICY}"

  # Attaching the policy to the IAM Role.
  echo -n "Attaching ${POLICY_ARN} ..."

  aws iam attach-role-policy \
      --role-name "${ESO_IAM_ROLE}" \
      --policy-arn "${POLICY_ARN}"

  echo "Attached."

  echo "===================================================="
  echo "Associating the Role with the Service Account"
  echo "===================================================="

  # Updating the Kubernetes Service Account with the new IAM Role
  declare IRSA_ROLE_ARN="eks.amazonaws.com/role-arn=${ESO_IAM_ROLE_ARN}"
  kubectl annotate serviceaccount -n ${NAMESPACE} ${ESO_SA_NAME} ${IRSA_ROLE_ARN}

}

install_eso
permissions_eso
