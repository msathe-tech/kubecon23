#!/bin/bash
source gcp_access_values.sh
source set_env_vars.sh
source setup_prod_attestor.sh

gcloud kms keys create "${PROD_KEY}" \
    --keyring "${PROD_KEYRING}" \
    --location "${LOCATION}" \
    --purpose "asymmetric-signing" \
    --default-algorithm "rsa-sign-pkcs1-2048-sha256"
gcloud kms keys add-iam-policy-binding "${PROD_KEY}" \
    --location="${LOCATION}" --keyring="${PROD_KEYRING}" \
    --member "serviceAccount:${GSA_NAME}@$PROJECT_ID.iam.gserviceaccount.com" --role "roles/cloudkms.cryptoOperator"
gcloud kms keys add-iam-policy-binding "${PROD_KEY}" \
    --location="${LOCATION}" --keyring="${PROD_KEYRING}" \
    --member "serviceAccount:${GSA_NAME}@$PROJECT_ID.iam.gserviceaccount.com" --role "roles/cloudkms.viewer"

#Allow default SA to pull images from Artifact Registrt
# gcloud projects add-iam-policy-binding $PROJECT_ID \
# --role=roles/artifactregistry.reader \
# --member=serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com

#Setup attestor associated with the note id for simple signing. 
gcloud container binauthz attestors create "${PROD_ATTESTOR_NAME}" \
--attestation-authority-note="${PROD_NOTE_ID}" \
--attestation-authority-note-project="${PROJECT_ID}"

# #allow attestor-sa to read notes
# gcloud projects add-iam-policy-binding $PROJECT_ID \
# --member="serviceAccount:${PROD_ATTESTOR_SA}" \
# --role=roles/containeranalysis.notes.occurrences.viewer

#add key to the attestor and override the public keyid to use "gcpkms://" 
gcloud container binauthz attestors public-keys add \
--attestor="${PROD_ATTESTOR_NAME}" \
--keyversion-project="${PROJECT_ID}" \
--keyversion-location="${LOCATION}" \
--keyversion-keyring="${PROD_KEYRING}" \
--keyversion-key="${PROD_KEY}" \
--keyversion="${PROD_KEY_VERSION}" \
--public-key-id-override="${PROD_KMS_URI}"

#apply binauth policy 
envsubst < binauth_policy_prod.yaml > hydrated_prod_binauth_policy.yaml
gcloud container binauthz policy import hydrated_prod_binauth_policy.yaml

