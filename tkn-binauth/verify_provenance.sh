
#!/bin/bash
source set_env_vars.sh

alias gcurl='curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $(gcloud auth print-access-token)"'

#get IMAGE DIGEST and URL from the last Pipeline Run
export IMAGE_DIGEST=$(tkn pr describe --last -o jsonpath="{.status.taskRuns..taskResults[?(@.name=='IMAGE_DIGEST')].value}")
export IMAGE_URL=$(tkn pr describe --last -o jsonpath="{.status.taskRuns..taskResults[?(@.name=='IMAGE_URL')].value}")


echo " Verify the SLSA provenance from drydock BUILD occurrence"
#Retrieve provenance 
gcurl https://containeranalysis.googleapis.com/v1/projects/$PROJECT_ID/occurrences\?filter\="resourceUrl=\"$IMAGE_URL@$IMAGE_DIGEST\"%20AND%20kind=\"BUILD\"" | \
jq -r '.occurrences[0].envelope.payload' | tr '\-_' '+/' | base64 -d > provenance

#Retrieve signature
gcurl https://containeranalysis.googleapis.com/v1/projects/$PROJECT_ID/occurrences\?filter\="resourceUrl=\"$IMAGE_URL@$IMAGE_DIGEST\"%20AND%20kind=\"BUILD\"" | \
jq -r '.occurrences[0].envelope.signatures[0].sig' | tr '\-_' '+/' | base64 -d > signature

#verify signature
cosign verify-blob --key $KMS_URI --signature signature signature 


echo "Press any key to continue"
while [ true ] ; do
read -t 10 -n 1
if [ $? = 0 ] ; then
break
else
echo "waiting for the keypress"
fi
done

echo "Verify the image attestation from drydock ATTESTATION occurrence"

#Retrieve provenance 
gcurl https://containeranalysis.googleapis.com/v1/projects/$PROJECT_ID/occurrences\?filter\="resourceUrl=\"$IMAGE_URL@$IMAGE_DIGEST\"%20AND%20kind=\"ATTESTATION\"" | \
jq -r '.occurrences[0].envelope.payload' | tr '\-_' '+/' | base64 -d > provenance

#Retrieve signature
gcurl https://containeranalysis.googleapis.com/v1/projects/$PROJECT_ID/occurrences\?filter\="resourceUrl=\"$IMAGE_URL@$IMAGE_DIGEST\"%20AND%20kind=\"ATTESTATION\"" | \
jq -r '.occurrences[0].envelope.signatures[0].sig' | tr '\-_' '+/' | base64 -d > signature

cosign verify-blob --key $KMS_URI --signature signature provenance 