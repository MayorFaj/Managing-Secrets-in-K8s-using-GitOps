# External Secrets Operator demo with AWS Secrets Manager and AWS Systems Manager Parameter Store

This repository consists of example codes (using kustomize and bash script) for installation of External Secrets Operator [(ESO)](https://external-secrets.io/) on an Amazon EKS Cluster and integration configurations with AWS Secrets Manager and AWS Systems Manager Parameter Store.

## Prerequisites

- A Kubernetes Cluster

- AWS IAM Permissions for creating and attaching IAM Roles

- Installation of required tools:

  - [AWS CLI](https://aws.amazon.com/cli/)

  - [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)

  - [Helm](https://helm.sh/docs/intro/install/)

  - [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform)

  - [eksctl](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html)

If you don't have a Kubernetes cluster, you can create an EKS cluster with Terraform [following this repository](https://github.com/MayorFaj/EKS-Terraform).

[Follow this repository](https://github.com/MayorFaj/Terraform-Codes-for-AWS-Secrets-Manager) to create and push secrets to AWS Secret Manager

When you want to install External Secrets Operator and configure IAM Permissions you can run `./eso_install.sh` 

**`or use  kustomize`**

`kubectl kustomize eso_kustomize/overlays/dev --enable-helm | kubectl apply -f -` 

The [script](./eso_install.sh) has two functions called install_eso and permissions_eso.

- Install_eso function installs the required ESO Helm Chart to the Kubernetes cluster.

- Permissions_eso function creates OIDC identity provider for the Kubernetes cluster and creates IAM Roles for for Service Accounts of the ESO.

### Cleanup

When you want to delete all the resources created in this repository, you can run `./cleanup.sh` script in the root directory of this repository.

The [script](./cleanup.sh) has one function and does the following:

- Uninstalls the Helm Chart of ESO

- Deletes the IAM Roles and Policies

- Deletes the OIDC Provider of EKS Cluster

- Deletes the EKS Cluster created with Terraform
