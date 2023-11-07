# Build Provenance using Tekton Chains and verify with Binary Authorization

## Prerequisites

Tools
* kubectl
* gcloud
* kubectx
* jq
* tkn - the CLI for tekton
* cosign to verify provenance


## Set up two clusters 

Here we will set up two clusters:
1. Tekton cluster to run Tekton pipelines and Tekton Chains configured using Workload Identity. This cluster will be used for CICD i.e., build application containers and deploy.
2. Workload cluster that is secured with Binary Authorization to run only those containers that meet the Binary Authorization criteria

### Edit the environment variables 
Edit [set_env_vars.sh](./set_env_vars.sh) to replace the values for environment variables such a project name, billing account, organization id, service accounts etc.
The GCP access values are in untracked [gcp_access_values.sh](./gcp_access_values.sh) file. 
You need to create this sh files and specify project ID, billing ID and username. 

### Create GKE clusters
Run the script that will create a project, enable required APIs and create two clusters

```
./01_setup_k8s_clusters.sh
```

Ensure all clusters are in running status by verifying using the command

```
gcloud container clusters list
```

## Install Tekton and Tekton Chains

On the Tekton cluster, we will now install Tekton, Tekton Pipelines and setup KMS key so that Tekton chains can attest using the key, and the chains configs are updated to be able to do so. Workload identity will be configured so that kubernetes service account has necessary access to push images to artifact registry. Google service account associated with this Kubernetes service account will be given necessary access through IAM.

```
./02_setup_tekton.sh
```

## Run Tekton pipeline to build a container

Review pipeline steps from this sample pipeline [kaniko-pipeline.yaml](./kaniko-pipeline.yaml). This pipeline uses two tasks. Create `git-clone` and `kaniko-chains` tasks from Tekton Hub and the pipeline by running.

```
./03_setup_tasks_pipeline.sh
```

Verify the tasks created by running `tkn tasks list` and pipelines by running `tkn pipelines list`

Execute the build pipeline by running the following two commands:

```
./05_build_app.sh
```

Verify provenance by running the following script

```
source ./06_verify_provenance.sh
```

You should see `Verified OK` message at the end of the provenance check indicating the provenance was good.

## Configure Binary Authorizaton for the workload cluster

Configure Attestor and the binary auth policy by running

```
./04_configure_binauth.sh
```

## Deploy workloads

You can repeate following steps for demos. 
Keep deleting - Workloads, Services and the Container images from the repo after every demo. This will keep the setup clean.

Try deploying workloads that are 
* not attested first, and it should fail due to BinAuthz policy
* attested by Tekton Chains, that should succeed deployment

```
./07_deploy_workloads.sh
```
See the pod for the `allowed` workload comes up and is running.

Check the events running `kubectl get events --sort-by=lastTimestamp` and you will see failure due to attestation for the `not-allowed` workload as below

```

22s         Warning   FailedCreate              replicaset/not-allowed-54c7d6d977                    
Error creating: admission webhook "imagepolicywebhook.image-policy.k8s.io" denied the request: Image docker.io/veermuchandi/welcome denied by Binary Authorization cluster admission rule for us-central1-c.wkload-cluster. Image docker.io/veermuchandi/welcome denied by attestor projects/veer-tkn-test1/attestors/tekton-chains-attestor: Expected digest with sha256 scheme, but got tag or malformed digest

```

## Optional: Promote the app to prod with additional attestations

Try the multi-attestor scenario with prod cluster
```
./08_deploy_prod_workloads.sh 
```


