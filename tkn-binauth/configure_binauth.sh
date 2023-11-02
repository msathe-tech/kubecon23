#!/bin/bash

source set_env_vars.sh

#Allow default SA to pull images from Artifact Registrt
gcloud projects add-iam-policy-binding $PROJECT_ID \
--role=roles/artifactregistry.reader \
--member=serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com

#Setup attestor associated with the note id for simple signing. 
gcloud container binauthz attestors create "${ATTESTOR_NAME}" \
--attestation-authority-note="${NOTE_ID}" \
--attestation-authority-note-project="${PROJECT_ID}"

#allow attestor-sa to read notes
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member="serviceAccount:${ATTESTOR_SA}" \
--role=roles/containeranalysis.notes.occurrences.viewer

#add key to the attestor and override the public keyid to use "gcpkms://" 
gcloud container binauthz attestors public-keys add \
--attestor="${ATTESTOR_NAME}" \
--keyversion-project="${PROJECT_ID}" \
--keyversion-location="${LOCATION}" \
--keyversion-keyring="${KEYRING}" \
--keyversion-key="${KEY}" \
--keyversion="${KEY_VERSION}" \
--public-key-id-override="${KMS_URI}"

#apply binauth policy 
envsubst < binauth_policy.yaml > hydrated_binauth_policy.yaml
gcloud container binauthz policy import hydrated_binauth_policy.yaml

