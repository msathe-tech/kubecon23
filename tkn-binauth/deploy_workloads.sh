#!/bin/bash
source set_env_vars.sh

wait_for_key () {
    echo "Press any key to continue"
    while [ true ] ; do
    read -t 10 -n 1
    if [ $? = 0 ] ; then
    break
    else
    echo "waiting for the keypress"
    fi
    done
}


#get IMAGE DIGEST and URL from the last Pipeline Run
kubectx tkn
export IMAGE_DIGEST=$(tkn pr describe --last -o jsonpath="{.status.taskRuns..taskResults[?(@.name=='IMAGE_DIGEST')].value}")
export IMAGE_URL=$(tkn pr describe --last -o jsonpath="{.status.taskRuns..taskResults[?(@.name=='IMAGE_URL')].value}")

#get security context and rename it to workload cluster
gcloud container clusters get-credentials --zone=${ZONE} "${WORKLOAD_CLUSTER}" 
kubectx workload-cluster=$(kubectx -c)


echo "Deploying a workload that should fail due to BinAuth Policy"
kubectl --context workload-cluster create deployment not-allowed --image=nginx

wait_for_key

echo "List events"
kubectl --context workload-cluster get events --sort-by=.metadata.creationTimestamp

wait_for_key

echo "Show if the pods were actually created"
kubectl --context workload-cluster get pods 

wait_for_key

echo "Deploying a workload that was attested"
kubectl --context workload-cluster create deployment allowed --image=${IMAGE_URL}@${IMAGE_DIGEST}

echo "Verify that the application is running"
kubectl --context workload-cluster get pods -n default -w



## Delete deployments
#kubectl --context workload-cluster delete deploy not-allowed
#kubectl --context workload-cluster delete deploy allowed

