
source set_env_vars.sh


#KMS 
gcloud kms keys remove-iam-policy-binding "${KEY}" \
    --location="${LOCATION}" --keyring="${KEYRING}" \
    --member "serviceAccount:${GSA_NAME}" --role "roles/cloudkms.cryptoOperator"
gcloud kms keys remove-iam-policy-binding "${KEY}" \
    --location="${LOCATION}" --keyring="${KEYRING}" \
    --member "serviceAccount:${GSA_NAME}" --role "roles/cloudkms.viewer"

gcloud kms keyrings delete "${KEYRING}" --location "${LOCATION}"

# IAM Policy Binding to let the KSA have access to the GSA.
gcloud iam service-accounts remove-iam-policy-binding $GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
--role roles/iam.workloadIdentityUser \
--member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/$KSA_NAME]"

#permission to push image to Artifact Registry
gcloud projects remove-iam-policy-binding $PROJECT_ID \
--member "serviceAccount:$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
--role "roles/artifactregistry.writer"

#permission to access KMS keys
gcloud projects remove-iam-policy-binding $PROJECT_ID \
--member "serviceAccount:$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
--role "roles/cloudkms.cryptoOperator"

gcloud projects remove-iam-policy-binding $PROJECT_ID \
--member "serviceAccount:$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
--role "roles/cloudkms.viewer"

#permission to access drydock/container analysis on the Artifact Registry
gcloud projects remove-iam-policy-binding $PROJECT_ID \
--member "serviceAccount:$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
--role "roles/containeranalysis.admin"

gcloud iam service-accounts delete $GSA_NAME \
  --project=$PROJECT_ID

gcloud container clusters delete ${TEKTON_CLUSTER}

gcloud container clusters delete ${WORKLOAD_CLUSTER}