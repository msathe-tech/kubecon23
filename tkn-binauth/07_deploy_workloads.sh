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


gcloud config set project $PROJECT_ID

gcloud container clusters get-credentials --region=us-central1 "${TEKTON_CLUSTER}" 
kubectx -c
kubectx tkn=$(kubectx -c)

#get IMAGE DIGEST and URL from the last Pipeline Run
export IMAGE_DIGEST=$(tkn pr describe --last -o jsonpath="{.status.taskRuns..taskResults[?(@.name=='IMAGE_DIGEST')].value}")
export IMAGE_URL=$(tkn pr describe --last -o jsonpath="{.status.taskRuns..taskResults[?(@.name=='IMAGE_URL')].value}")

echo "Switching context to workload cluster"
#get security context and rename it to workload cluster
gcloud container clusters get-credentials --zone=${ZONE} "${WORKLOAD_CLUSTER}" 
kubectx -c
kubectx workload-cluster=$(kubectx -c)

echo ""
echo "*********"
echo "*********"
echo "Deploying a workload that should fail due to BinAuth Policy"
echo "*********"
echo "*********"
echo ""
kubectl --context workload-cluster create deployment not-allowed --image=nginx

wait_for_key

# echo "List events"
# kubectl --context workload-cluster get events --sort-by=.metadata.creationTimestamp

# wait_for_key
echo ""
echo "*********"
echo "*********"
echo "Visit GKE Workloads page on console to check if the pods were actually created"
echo "*********"
echo "*********"
echo ""
# kubectl --context workload-cluster get pods -o wide

wait_for_key

echo ""
echo "*********"
echo "*********"
echo "Deploying a workload that was attested"
echo "*********"
echo "*********"
echo ""
#kubectl --context workload-cluster create deployment allowed --image=${IMAGE_URL}@${IMAGE_DIGEST}
cat > allowed-k8s.yaml << ENDOFFILE
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: foo
  name: foo  
spec:
  replicas: 1
  selector:
    matchLabels:
      app: foo
  template:
    metadata:
      labels:
        app: foo
    spec:
      containers:
      # Please change this to your Docker repo
      - image: ${IMAGE_URL}@${IMAGE_DIGEST}
        imagePullPolicy: Always
        name: foo
        # resources:
        #   limits:
        #     cpu: "1"
        #     memory: 256Mi
        #   requests:
        #     cpu: "0.5"
        env:
          - name: HOST_IP
            valueFrom:
              fieldRef:
                fieldPath: status.hostIP
          - name: POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          - name: POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP
          - name: NODE_NAME
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
          - name: POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: POD_SERVICE_ACCOUNT
            valueFrom:
              fieldRef:
                fieldPath: spec.serviceAccountName
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: 8080
          initialDelaySeconds: 2
          timeoutSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 2
          timeoutSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: foo-service
spec:
  selector:
    app: foo
  ports:
  - port: 8080
    targetPort: 8080
  type: LoadBalancer
ENDOFFILE

kubectl --context workload-cluster apply -f allowed-k8s.yaml

echo ""
echo "*********"
echo "*********"
echo "Verify that the application is running"
echo "*********"
echo "*********"
echo ""
# kubectl --context workload-cluster get pods -n default -w

## Delete deployments
#kubectl --context workload-cluster delete deploy not-allowed
#kubectl --context workload-cluster delete deploy allowed

