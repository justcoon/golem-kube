#!/bin/bash

usage() { echo "Usage: $0 -n <NAMESPACE>" 1>&2; exit 1; }

while getopts "n:" o; do
    case "${o}" in
        n)
            NAMESPACE=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z "$NAMESPACE" ]]; then
    usage
fi

INGRESS_NAMESPACE=ingress-nginx

kubectl get namespace $INGRESS_NAMESPACE > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Installing ingress-nginx to namespace $INGRESS_NAMESPACE"
  helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace $INGRESS_NAMESPACE --create-namespace
else
  echo "ingress-nginx namespace $INGRESS_NAMESPACE already exists, do not executing installation"
fi

echo ""
echo "Creating namespace $NAMESPACE"

kubectl create namespace $NAMESPACE

echo ""
echo "Installing PostgreSQL to namespace $NAMESPACE"

helm upgrade --install -n $NAMESPACE golem-postgres oci://registry-1.docker.io/bitnamicharts/postgresql --set auth.database=golem_db --set auth.username=golem_user

echo ""
echo "Installing Redis to namespace $NAMESPACE"

helm upgrade --install -n $NAMESPACE golem-redis oci://registry-1.docker.io/bitnamicharts/redis --set auth.enabled=true

#echo ""
#echo "Installing Minio to namespace $NAMESPACE"
#
#helm upgrade --install golem-minio --namespace $NAMESPACE --set resources.requests.memory=768Mi --set replicas=1 --set persistence.enabled=false --set mode=standalone --set "rootUser=minioroot,rootPassword=minioadmin,users[0].accessKey=minioadmin,users[0].secretKey=minioadmin,users[0].policy=readwrite,buckets[0].name=compilation-cache,buckets[0].policy=none,buckets[0].purge=false,buckets[1].name=custom-data,buckets[1].policy=none,buckets[1].purge=false,buckets[2].name=oplog-payload,buckets[2].policy=none,buckets[2].purge=false,buckets[3].name=oplog-archive-1,buckets[3].policy=none,buckets[3].purge=false,buckets[4].name=component-store,buckets[4].policy=none,buckets[4].purge=false,buckets[5].name=initial-component-files,buckets[5].policy=none,buckets[5].purge=false,buckets[6].name=plugin-wasm-files,buckets[6].policy=none,buckets[6].purge=false" minio/minio

echo ""
echo "Waiting 30s for services to startup up ..."

sleep 30

echo ""
echo "Installing Golem to namespace $NAMESPACE"

kubectl create serviceaccount -n $NAMESPACE golem-sa-default

helm upgrade --install golem-default golem-chart -n $NAMESPACE

echo ""
echo "Waiting 30s for Golem to startup up ..."

sleep 30

echo ""
./check_golem_readiness.sh -n $NAMESPACE
if [[ $? -ne 0 ]]; then
  echo "Checking Golem readiness namespace: $NAMESPACE failed"
fi

echo ""
echo "Installation done"

echo ""
echo "To show all kubernetes components for namespace $NAMESPACE, run:"
echo "kubectl -n $NAMESPACE get all"

echo ""
echo "Use http://localhost:80 in golem-cli"

echo ""
