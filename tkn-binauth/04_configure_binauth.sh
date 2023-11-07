#!/bin/bash
source gcp_access_values.sh
source set_env_vars.sh
source setup_prod_attestor.sh

gcloud config set project $PROJECT_ID

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


#### Setup prod config for binary authorization

# First create a Note and give IAM policy for the Note
echo "Now let us add Prod attestation to the same image and try the deployment again"
echo "This will demonstrate how an image can accumulate trust/attestation as it moves from lower to higher env"

echo "Let us first create a prod note"
cat > prod_note_payload.json << EOM
{
  "name": "${PROD_NOTE_ID}",
  "attestation": {
    "hint": {
      "human_readable_name": "${PROD_NOTE_DESCRIPTION}"
    }
  }
}
EOM

curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)"  \
    -H "x-goog-user-project: ${PROJECT_ID}" \
    --data-binary @./prod_note_payload.json  \
    "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/?noteId=${PROD_NOTE_NAME}"

echo "Set IAM permissions on the note"
cat > prod_note_iam_request.json << EOM
{
  "resource": "${PROD_NOTE_ID}",
  "policy": {
    "bindings": [
      {
        "role": "roles/containeranalysis.notes.occurrences.viewer",
        "members": [
          "serviceAccount:${PROD_ATTESTOR_SA}"
        ]
      }
    ]
  }
}
EOM

curl -X POST  \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "x-goog-user-project: ${PROJECT_ID}" \
    --data-binary @./prod_note_iam_request.json \
    "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/${PROD_NOTE_NAME}:setIamPolicy"

##

echo "Checking for existence of KEYRING ${PROD_KEYRING}..."
if gcloud kms keyrings describe "${PROD_KEYRING}" --location "${LOCATION}"; then
  echo "KEYRING ${PROD_KEYRING} found."
else
  echo "KEYRING ${PROD_KEYRING} NOT found. Creating it now."
  gcloud kms keyrings create "${PROD_KEYRING}" --location "${LOCATION}"
  echo "KEYRING ${PROD_KEYRING} created successfully."
fi

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
echo "Creating the prod attestor now"
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

##### 

echo "Show all the attestors in the project"
gcloud container binauthz attestors list

wait_for_key

#apply binauth policy 
envsubst < binauth_policy.yaml > hydrated_binauth_policy.yaml
gcloud container binauthz policy import hydrated_binauth_policy.yaml

echo "Verify the attestors from console"