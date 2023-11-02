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

### Create GKE clusters
Run the script that will create a project, enable required APIs and create two clusters

```
./setup_k8s_clusters.sh
```
Ensure both clusters are in running status by verifying using the command

```
gcloud container clusters list
```

## Install Tekton and Tekton Chains

On the Tekton cluster, we will now install Tekton, Tekton Pipelines and setup KMS key so that Tekton chains can attest using the key, and the chains configs are updated to be able to do so. Workload identity will be configured so that kubernetes service account has necessary access to push images to artifact registry. Google service account associated with this Kubernetes service account will be given necessary access through IAM.

```
./setup_tekton.sh
```

## Run Tekton pipeline to build a container

Review pipeline steps from this sample pipeline [kaniko-pipeline.yaml](./kaniko-pipeline.yaml). This pipeline uses two tasks. Create `git-clone` and `kaniko-chains` tasks from Tekton Hub and the pipeline by running.

```
./setup_tasks_pipeline.sh
```

Verify the tasks created by running `tkn tasks list` and pipelines by running `tkn pipelines list`

Execute the build pipeline by running the following two commands:

```
source set_env_vars.sh
tkn pipeline start kaniko-test-pipeline \
-p image=${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO}/fooapp \
--pod-template=pod-template.yaml \
-p source_url=https://github.com/slsa-demo/foo-app \
-w name=source-workspace,claimName=workspace-pvc \
-w name=cache-workspace,emptyDir="" \
-s tekton-ksa \
--use-param-defaults \
--showlog
```

Authenticate to gcloud to retrieve the Application Default Credentials

```
gcloud auth application-default login
```

Verify provenance by running the following script

```
source verify_provenance.sh
```

You should see `Verified OK` message at the end of the provenance check indicating the provenance was good.

## Configure Binary Authorizaton for the workload cluster

Configure Attestor and the binary auth policy by running

```
./configure_binauth.sh
```

## Deploy workloads

Try deploying workloads that are 
* not attested first, and it should fail due to BinAuthz policy
* attested by Tekton Chains, that should succeed deployment

```
./deploy_workloads.sh
```
See the pod for the `allowed` workload comes up and is running.

Check the events running `kubectl get events --sort-by=lastTimestamp` and you will see failure due to attestation for the `not-allowed` workload as below

```

22s         Warning   FailedCreate              replicaset/not-allowed-54c7d6d977                    
Error creating: admission webhook "imagepolicywebhook.image-policy.k8s.io" denied the request: Image docker.io/veermuchandi/welcome denied by Binary Authorization cluster admission rule for us-central1-c.wkload-cluster. Image docker.io/veermuchandi/welcome denied by attestor projects/veer-tkn-test1/attestors/tekton-chains-attestor: Expected digest with sha256 scheme, but got tag or malformed digest

```







