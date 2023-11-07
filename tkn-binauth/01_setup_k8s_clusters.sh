#!/bin/bash

source gcp_access_values.sh
source set_env_vars.sh

#create project
gcloud projects create $PROJECT_ID --organization=$ORGANIZATION_ID
#associate billing account
gcloud beta billing projects link ${PROJECT_ID} --billing-account=$BILLING_ACCOUNT

gcloud config set project $PROJECT_ID
gcloud auth application-default login --no-launch-browser


#If running on Argolis, uncomment below
source arg_k8s_perms.sh

#Enable required APIs
gcloud services enable artifactregistry.googleapis.com
gcloud services enable binaryauthorization.googleapis.com --async # Binary Authorization
gcloud services enable cloudkms.googleapis.com --async            # KMS
#gcloud services enable compute.googleapis.com --async             # GCE
gcloud services enable container.googleapis.com --async           # GKE
gcloud services enable containeranalysis.googleapis.com --async   # Container Analysis
gcloud services enable containerfilesystem.googleapis.com --async # Streaming Images
gcloud services enable iam.googleapis.com --async                 # IAM

#create Tekton Cluster that runs pipelines and chains
gcloud container clusters create $TEKTON_CLUSTER \
--enable-autoscaling \
--min-nodes=2 \
--max-nodes=4 \
--enable-image-streaming \
--scopes=cloud-platform \
--no-issue-client-certificate \
--project="${PROJECT_ID}" \
--region="${LOCATION}" \
--machine-type=n1-standard-4 \
--image-type="COS_CONTAINERD" \
--num-nodes=2 \
--cluster-version=latest \
--workload-pool=$PROJECT_ID.svc.id.goog &

#create Workload cluster with binauthz, that runs your application
gcloud container clusters create "${WORKLOAD_CLUSTER}" \
--binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE \
--enable-autoscaling \
--min-nodes=2 \
--max-nodes=4 \
--image-type="COS_CONTAINERD" \
--enable-image-streaming  \
--num-nodes=2 --zone="${ZONE}" \
--machine-type="n1-standard-4" &

#create Prod cluster with binauthz, that runs your application
gcloud container clusters create "${PROD_CLUSTER}" \
--binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE \
--enable-autoscaling \
--min-nodes=2 \
--max-nodes=6 \
--image-type="COS_CONTAINERD" \
--enable-image-streaming  \
--num-nodes=2 --zone="${ZONE}" \
--machine-type="n1-standard-4" &

# Set up Artifact Registry: create a docker repository 
gcloud artifacts repositories create "${ARTIFACT_REPO}" \
    --repository-format=docker --location="${LOCATION}"

# Check the cluster status 
gcloud container clusters list
