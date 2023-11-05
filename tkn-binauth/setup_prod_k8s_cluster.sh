#!/bin/bash

source gcp_access_values.sh
source set_env_vars.sh

#create Workload cluster with binauthz, that runs your application
gcloud container clusters create "${PROD_CLUSTER}" \
--binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE \
--enable-autoscaling \
--min-nodes=1 \
--max-nodes=5 \
--image-type="COS_CONTAINERD" \
--enable-image-streaming  \
--num-nodes=1 --zone="${ZONE}" \
--machine-type="n1-standard-4"