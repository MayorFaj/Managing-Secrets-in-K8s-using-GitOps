# ☸ Managing secrets effectively in K8s using GitOps without compromising security ☸

Since GitOps relies heavily on Git  for storing application logic, infrastructure manifests, and application manifests. However, securely managing secrets can be a challenge, as storing them in Git repositories can pose a security risk if they are not managed properly.

Let's discuss one of the fundamental approach to managing secrets.

## **Storing a reference to a secret**

When storing a reference to a secret, you store the secrets in some kind of backend  like AWS Secrets Manager, HashiCorp Vault, Google Secrets Manager, Azure Key Vault, etc.

What's next? Use a tool like External Secret Operator to declaratively specify which secrets you need, the operator reads the information from the backend/external API and automatically injects the values into a Kubernetes secret.

## **External Secret Operator ESO**

The goal of ESO is to synchronize secrets from external APIs into Kubernetes.

**ESO is a collection of custom API resources;**

1️⃣  ExternalSecret 

2️⃣  SecretStore

3️⃣  ClusterSecretStore 

This provides a user-friendly abstraction for the external API that stores and manages the lifecycle of the secrets for you.


### **1️⃣  EXTERNAL SECRET**

An External Secret declares what data to fetch. It has a reference to a SecretStore or ClusterSecretStore which knows how to access that data.

The controller uses that ExternalSecret as a blueprint to create secrets in the cluster.



### **2️⃣  SECRET STORE/CLUSTER SECRET STORE**
A SecretStore points to AWS Secrets Manager in a certain account within a defined region
The **SecretStore** specifies how to access. Note; secret store is namespaced, while **ClusterSecretStore** is global, and can be referenced from all namespaces.

Use to provide a central gateway to your secret provider (In this case, AWS Secret Manager).

### **2️⃣  PUSH SECRET**
The PushSecret is namespaced and it describes what data should be pushed to the secret provider.

## **BEHAVIOUR**

The External Secret Operator reconciles ExternalSecrets in the following manner;

- *️⃣ ESO uses spec.secretStoreRef to find an appropriate SecretStore. If it doesn't exist or the spec.controller field doesn't match it won't further process this ExternalSecret.

- ⏭ ESO instanciates an external API client using the specified credentials from the SecretStore spec.



- ⏭  ESO fetches the secrets as requested by the ExternalSecret, it will decode the secrets if required



- ⏭  ESO creates an Kind=Secret based on the template provided by ExternalSecret.target.template. The Secret.data can be templated using the secret values from the external API.



- ⏯  ESO ensures that the secret values stay in sync with the external API 

## **AWS AUTHENTICATION**

Secrets backends can authenticate with K8s in a few different ways. One of the options is to configure a Kubernetes service account to assume an IAM role (IRSA), then reference the service account created in the Secret Store
This feature lets you use short-lived service account tokens to authenticate with AWS rather.


## PERMISSIONS

### IAM Policy

Create a IAM Policy to pin down access to secrets matching dev-*.

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-west-2:111122223333:secret:dev-*",
        "arn:aws:iam::111111222222:role/external-secret-operator"
      ]
    }
  ]
}
```

### Permissions for PushSecret

If you're planning to use PushSecret, ensure you also have the following permissions in your IAM policy:

```
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:CreateSecret",
    "secretsmanager:PutSecretValue",
    "secretsmanager:TagResource",
    "secretsmanager:DeleteSecret"
  ],
  "Resource": [
    "arn:aws:secretsmanager:us-west-2:111122223333:secret:dev-*"
  ]
}
```

Here's a more restrictive version of the IAM policy:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:PutSecretValue",
        "secretsmanager:TagResource"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-west-2:111122223333:secret:dev-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:DeleteSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-west-2:111122223333:secret:dev-*"
      ],
      "Condition": {
        "StringEquals": {
          "secretsmanager:ResourceTag/managed-by": "external-secrets"
        }
      }
    }
  ]
}
```