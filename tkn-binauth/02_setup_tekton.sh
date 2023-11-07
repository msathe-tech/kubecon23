#!/bin/bash

source set_env_vars.sh

gcloud config set project $PROJECT_ID

#get security context and rename it to tkn
gcloud container clusters get-credentials --region=us-central1 "${TEKTON_CLUSTER}" 
kubectx -c
kubectx tkn=$(kubectx -c)

#create kubernetes service account to associate with workload identity
kubectl create serviceaccount $KSA_NAME \
  --namespace $NAMESPACE

#create Google service account to which IAM permissions will be granted
gcloud iam service-accounts create $GSA_NAME \
  --project=$PROJECT_ID

echo "Kubernetes SA and Google SA created"

## GRANT PERMISSIONS to the Google service account

#permission to push image to Artifact Registry
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member "serviceAccount:$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
--role "roles/artifactregistry.writer"

#permission to access KMS keys
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member "serviceAccount:$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
--role "roles/cloudkms.cryptoOperator"

gcloud projects add-iam-policy-binding $PROJECT_ID \
--member "serviceAccount:$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
--role "roles/cloudkms.viewer"

#permission to access drydock/container analysis on the Artifact Registry
#used both by the builder during pipeline run by Tekton and verifier during tekton chains
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member "serviceAccount:$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
--role "roles/containeranalysis.admin"

echo "Permissions granted to Google Service Account"

## WORKLOAD IDENTITY MAPPING

#Add an IAM Policy Binding to let the KSA have access to the GSA.
gcloud iam service-accounts add-iam-policy-binding $GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
--role roles/iam.workloadIdentityUser \
--member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/$KSA_NAME]"

#Annotate the KSA to point to the GSA to use
kubectl annotate serviceaccount $KSA_NAME \
  --namespace $NAMESPACE \
  iam.gke.io/gcp-service-account=$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com

echo "Workload Identity Mapping done"

#install tekton pipeline
#kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.40.2/release.yaml

# Wait for pipelines to be ready.
unset status
while [[ "${status}" -ne "Running" ]]; do
  echo "Waiting for Tekton Pipelines installation to complete."
  status=$(kubectl get pods --namespace tekton-pipelines -o custom-columns=':status.phase' | sort -u)
done
echo "Tekton Pipelines installation completed."

#install tekton chains
#kubectl apply --filename https://storage.googleapis.com/tekton-releases/chains/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/chains/previous/v0.12.0/release.yaml


## Key Management Service
#Add Keyring and Key that will be used by Tekton chains to sign attestations
unset status
while [[ "${status}" -ne "Running" ]]; do
  echo "Waiting for Tekton Chains installation to complete."
  status=$(kubectl get pods --namespace tekton-chains -o custom-columns=':status.phase' | sort -u)
done
echo "Tekton Chains installation completed."

echo "Checking for existence of KEYRING ${KEYRING}..."
if gcloud kms keyrings describe "${KEYRING}" --location "${LOCATION}"; then
  echo "KEYRING ${KEYRING} found."
else
  echo "KEYRING ${KEYRING} NOT found. Creating it now."
  gcloud kms keyrings create "${KEYRING}" --location "${LOCATION}"
  echo "KEYRING ${KEYRING} created successfully."
fi

gcloud kms keys create "${KEY}" \
    --keyring "${KEYRING}" \
    --location "${LOCATION}" \
    --purpose "asymmetric-signing" \
    --default-algorithm "rsa-sign-pkcs1-2048-sha256"
gcloud kms keys add-iam-policy-binding "${KEY}" \
    --location="${LOCATION}" --keyring="${KEYRING}" \
    --member "serviceAccount:${GSA_NAME}@$PROJECT_ID.iam.gserviceaccount.com" --role "roles/cloudkms.cryptoOperator"
gcloud kms keys add-iam-policy-binding "${KEY}" \
    --location="${LOCATION}" --keyring="${KEYRING}" \
    --member "serviceAccount:${GSA_NAME}@$PROJECT_ID.iam.gserviceaccount.com" --role "roles/cloudkms.viewer"

# Configure Tekton Chains to use simplesigning of images; TaskRuns will be
# captured using in-toto. Attestations for both will be signed with a KMS key
# and stored in both grafeas (Container Analysis) and in OCI bundles alongside
# the image itself in Artifact Registry.
kubectl patch configmap chains-config -n tekton-chains \
    -p='{"data":{
    "artifacts.oci.format":      "simplesigning",
    "artifacts.oci.signer":      "kms",
    "artifacts.oci.storage":     "grafeas,oci",
    "artifacts.taskrun.format":  "in-toto",
    "artifacts.taskrun.signer":  "kms",
    "artifacts.taskrun.storage": "grafeas,oci" }}'

kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"storage.grafeas.projectid": "'"$PROJECT_ID"'"}}'
kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"signers.kms.kmsref": "'"$KMS_URI"'"}}'

## DONOT set note id - chains will create a note named tekton-<NAMESPACE>-simplesigning 
#kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"storage.grafeas.noteid": "'"$NOTE_ID"'"}}'


#Workload identity mapping to Tekton Chains Controller
gcloud iam service-accounts add-iam-policy-binding $GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
--role roles/iam.workloadIdentityUser \
--member "serviceAccount:$PROJECT_ID.svc.id.goog[tekton-chains/tekton-chains-controller]"

kubectl annotate serviceaccount tekton-chains-controller \
--namespace tekton-chains \
iam.gke.io/gcp-service-account=$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com