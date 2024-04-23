#!/bin/bash
set -e
: '
The following script cleans up the resources created in
this repository gracefully.
'

declare AWS_REGION="eu-central-1"
declare EKS_CLUSTER_NAME="rias-touch-cluster"
declare ESO_SYSTEM_NAMESPACE="external-secrets"

cleanup_eso(){

  echo "===================================================="
  echo "Creating required Environment Variables."
  echo "===================================================="

  declare ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
  declare OIDCURL=$(aws eks describe-cluster --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION} --query "cluster.identity.oidc.issuer" --output text | sed -r 's/https:\/\///')

  echo "===================================================="
  echo "Uninstalling the External Secrets Operator."
  echo "===================================================="  

  helm uninstall -n "$ESO_SYSTEM_NAMESPACE" external-secrets

  echo "===================================================="
  echo "Deleting IAM Role and Policy."
  echo "====================================================" 

  ESO_IAM_POLICY="eso_secrets_manager_policy"
  POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${ESO_IAM_POLICY}"
  ESO_IAM_ROLE="eso-iam-role"

  aws iam detach-role-policy --policy-arn ${POLICY_ARN} --role-name eso-iam-role
  aws iam delete-policy --policy-arn ${POLICY_ARN}
  aws iam delete-role --role-name ${ESO_IAM_ROLE}

  echo "===================================================="
  echo "Deleting the Kubernetes Service Account."
  echo "====================================================" 

  ESO_SA_NAME="external-secrets-operator-sa"
  kubectl delete sa ${ESO_SA_NAME}

  echo "===================================================="
  echo "Deleting the Kubernetes Namespace."
  echo "====================================================" 

  kubectl delete namespace "$ESO_SYSTEM_NAMESPACE"

  echo "===================================================="
  echo "Deleting the OIDC Provider."
  echo "====================================================" 

  aws iam delete-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDCURL}

  echo "===================================================="
  echo "Deleting the EKS Cluster."
  echo "====================================================" 

  terraform destroy --auto-approve
}

cleanup_eso