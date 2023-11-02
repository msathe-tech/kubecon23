
#!/bin/bash

#switch context to tekton cluster
kubectx tkn

#install tasks git-clone and kaniko-chains from tekton hub
tkn hub install task git-clone
#kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.1/git-clone.yaml
#tkn hub install task kaniko
kubectl apply -f https://api.hub.tekton.dev/v1/resource/tekton/task/kaniko/0.6/raw

#install pipeline that uses kaniko to build container
#kubectl apply -f kaniko-pipeline.yaml
kubectl apply -f https://raw.githubusercontent.com/slsa-demo/tkn-binauth/main/kaniko-pipeline.yaml

#create PVC for the workspace shared across taks
kubectl apply -f workspace-pvc.yaml


