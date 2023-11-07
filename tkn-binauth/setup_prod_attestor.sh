export PROD_KEYRING=tekton-chains-prod-ring
export PROD_KEY=tekton-chains-prod-key
export PROD_KEY_VERSION=1
export PROD_KMS_URI="gcpkms://projects/${PROJECT_ID}/locations/${LOCATION}/keyRings/${PROD_KEYRING}/cryptoKeys/${PROD_KEY}/cryptoKeyVersions/${PROD_KEY_VERSION}"

export PROD_ATTESTOR_NAME=tekton-chains-prod-attestor
export PROD_NOTE_NAME=prod-simplesigning
export PROD_NOTE_ID=projects/${PROJECT_ID}/notes/${PROD_NOTE_NAME}
export PROD_ATTESTOR_SA=service-${PROJECT_NUMBER}@gcp-sa-binaryauthorization.iam.gserviceaccount.com
export PROD_NOTE_DESCRIPTION="promote to prod"