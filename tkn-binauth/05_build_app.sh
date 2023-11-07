#!/bin/bash
source gcp_access_values.sh
source set_env_vars.sh
source setup_prod_attestor.sh

gcloud config set project $PROJECT_ID

gcloud container clusters get-credentials --region=us-central1 "${TEKTON_CLUSTER}" 
kubectx -c
kubectx tkn=$(kubectx -c)

echo "Building the application...."
tkn pipeline start kaniko-test-pipeline \
-p image=${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO}/fooapp \
--pod-template=pod-template.yaml \
-p source_url=https://github.com/slsa-demo/foo-app \
-w name=source-workspace,claimName=workspace-pvc \
-w name=cache-workspace,emptyDir="" \
-s tekton-ksa \
--use-param-defaults \
--showlog

#get IMAGE DIGEST and URL from the last Pipeline Run
export IMAGE_DIGEST=$(tkn pr describe --last -o jsonpath="{.status.taskRuns..taskResults[?(@.name=='IMAGE_DIGEST')].value}")
export IMAGE_URL=$(tkn pr describe --last -o jsonpath="{.status.taskRuns..taskResults[?(@.name=='IMAGE_URL')].value}")
