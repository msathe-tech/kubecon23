#!/bin/bash
source set_env_vars.sh
source ./setup_prod_attestor.sh 

wait_for_key () {
    echo "...."
    echo "Press any key to continue"
    while [ true ] ; do
    read -t 10 -n 1
    if [ $? = 0 ] ; then
    break
    else
    echo "...."
    echo "waiting for the keypress"
    fi
    done
}


#get IMAGE DIGEST and URL from the last Pipeline Run
gcloud container clusters get-credentials --region=us-central1 "${TEKTON_CLUSTER}" 
kubectx -c
kubectx tkn=$(kubectx -c)
export IMAGE_DIGEST=$(tkn pr describe --last -o jsonpath="{.status.taskRuns..taskResults[?(@.name=='IMAGE_DIGEST')].value}")
export IMAGE_URL=$(tkn pr describe --last -o jsonpath="{.status.taskRuns..taskResults[?(@.name=='IMAGE_URL')].value}")

#get security context and rename it to workload cluster
gcloud container clusters get-credentials --zone=${ZONE} "${PROD_CLUSTER}" 
kubectx prod-cluster=$(kubectx -c)

wait_for_key

echo ""
echo "*********"
echo "*********"
echo "Deploying a workload that was attested with one attestation only"
echo "*********"
echo "*********"
echo ""

# deploy to prod - this should fail for the first time
kubectl --context prod-cluster apply -f allowed-k8s.yaml

echo ""
echo "*********"
echo "*********"
echo "Check GCP console if the prod deployment was successful"
echo "*********"
echo "*********"
echo ""
# echo "Check if the application is running"
# kubectl --context prod-cluster get deployment -n default
wait_for_key
echo "We will now add prod attestation to the image and retry the deployment"
wait_for_key

# echo "We will have to use --public-key-id-override since flag was provided when this KMS key was added to the Attestor."

# try :latest instead of a digest 
gcloud beta container binauthz attestations sign-and-create \
    --project="${PROJECT_ID}" \
    --artifact-url="${IMAGE_URL}@${IMAGE_DIGEST}" \
    --attestor="${PROD_ATTESTOR_NAME}" \
    --attestor-project="${PROJECT_ID}" \
    --keyversion-project="${PROJECT_ID}" \
    --keyversion-location="${LOCATION}" \
    --keyversion-keyring="${PROD_KEYRING}" \
    --keyversion-key="${PROD_KEY}" \
    --keyversion="${PROD_KEY_VERSION}" \
    --public-key-id-override="${PROD_KMS_URI}"

echo ""
echo "*********"
echo "*********"
echo "Verify that new the attestation was created"
echo "*********"
echo "*********"
echo ""
wait_for_key

gcloud container binauthz attestations list\
    --project="${PROJECT_ID}" \
    --attestor="projects/${PROJECT_ID}/attestors/${PROD_ATTESTOR_NAME}" \
    --artifact-url="${IMAGE_URL}@${IMAGE_DIGEST}"

wait_for_key
echo "Delete the bad deployment and add it again" 
kubectl --context prod-cluster delete -f allowed-k8s.yaml
wait_for_key
echo "*********"
echo "*********"
echo ""
kubectl --context prod-cluster apply -f allowed-k8s.yaml
echo ""
echo "*********"
echo "*********"
echo "Check the GCP console if the prod deployment is successful after adding new attestation"