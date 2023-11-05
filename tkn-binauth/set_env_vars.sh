#!/bin/bash

export PROJECT_ID=kubecon23-2
# fill in your values here before execution 
# export ORGANIZATION_ID=<your-org-id> 
# export BILLING_ACCOUNT=<your-billing-id>
# export GCP_USER_ACCOUNT=<your-gcp-user-name>
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

export TEKTON_CLUSTER=tkn-cluster
export WORKLOAD_CLUSTER=wkload-cluster
export PROD_CLUSTER=prod-cluster
export ARTIFACT_REPO=my-repo

export KSA_NAME=tekton-ksa
export NAMESPACE=default
export GSA_NAME=tekton-gsa

export KEYRING=tekton-chains-ring
export LOCATION=us-central1
export ZONE=us-central1-c
export KEY=tekton-chains-key
export KEY_VERSION=1
export KMS_URI="gcpkms://projects/${PROJECT_ID}/locations/${LOCATION}/keyRings/${KEYRING}/cryptoKeys/${KEY}/cryptoKeyVersions/${KEY_VERSION}"

export ATTESTOR_NAME=tekton-chains-attestor
export NOTE_ID=projects/${PROJECT_ID}/notes/tekton-default-simplesigning
export ATTESTOR_SA=service-${PROJECT_NUMBER}@gcp-sa-binaryauthorization.iam.gserviceaccount.com
