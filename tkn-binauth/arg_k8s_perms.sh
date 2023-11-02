## If you are running on argolis, prepare project to run GKE clusters

# argolis user account
GCP_USER_ACCOUNT=[USER]@[ARGOLISACCOUNT]].altostrat.com

gcloud config set project ${PROJECT_ID}

PROJECT_NUMBER=$(gcloud projects list \
--filter="$(gcloud config get-value project)" \
--format="value(PROJECT_NUMBER)")

gcloud services enable \
    orgpolicy.googleapis.com \
    compute.googleapis.com

#create default network
gcloud compute networks create default --subnet-mode=auto

sleep 1m

# external IP for VM instances
cat > vmExternalIP.yaml << ENDOFFILE
name: projects/$PROJECT_ID/policies/compute.vmExternalIpAccess
spec:
 rules:
 - allowAll: true
ENDOFFILE

gcloud org-policies set-policy vmExternalIP.yaml --project=$PROJECT_ID

cat > dontRequireOSLogin.yaml << ENDOFFILE
name: projects/$PROJECT_ID/policies/compute.requireOsLogin
spec:
 rules:
 - enforce: false
ENDOFFILE

gcloud org-policies set-policy dontRequireOSLogin.yaml --project=$PROJECT_ID

cat > dontRequireShieldedVm.yaml << ENDOFFILE
name: projects/$PROJECT_ID/policies/compute.requireShieldedVm
spec:
 rules:
 - enforce: false
ENDOFFILE

gcloud org-policies set-policy dontRequireShieldedVm.yaml --project=$PROJECT_ID

# Grant your GCP account owner role on the new project
gcloud projects add-iam-policy-binding $PROJECT_ID --member=user:$GCP_USER_ACCOUNT --role=roles/owner

# Grant default service account Storage Object Viewer role, to access GCR
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com --role=roles/storage.objectViewer

# Grant default service account Kubernetes Engine Node Service Agent role
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com --role=roles/container.nodeServiceAgent

# Grant default service account Artifact Registry Reader role
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com --role=roles/artifactregistry.reader