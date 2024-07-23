#!/bin/bash

CONFIG_FILE="creds.conf"
SUPPORT_FILE="support.sh"
CERT_MANAGER_URL="https://github.com/cert-manager/cert-manager/releases/download/v1.15.1/cert-manager.yaml"
CERT_MANAGER_NAMESPACE="cert-manager"
NAMESPACE="default"
FLINK_OPERATOR_CHART="https://downloads.apache.org/flink/flink-kubernetes-operator-1.8.0/"
KAFKA_UI_PORT=8080
KAFKA_UI_CHART=https://provectus.github.io/kafka-ui-charts
FLINK_CLUSTER_DEPLOYMENT="flink-cluster.yaml"


# Check if the configuration file exists
if [ ! -f $SUPPORT_FILE ]; then
    echo "Support file not found: $SUPPORT_FILE"
    exit 1
fi

source $SUPPORT_FILE

if ! command -v helm &> /dev/null; then
    echo "helm could not be found, please install it."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "kubectl could not be found, please install it."
    exit 1
fi

echo "Checking if cert-manager is installed..."
if ! kubectl get ns $CERT_MANAGER_NAMESPACE &> /dev/null; then
    echo "cert-manager not found, installing..."
    kubectl apply -f $CERT_MANAGER_URL
    echo "Waiting for cert-manager to be ready..."
    kubectl rollout status deployment/cert-manager -n $CERT_MANAGER_NAMESPACE
    kubectl rollout status deployment/cert-manager-webhook -n $CERT_MANAGER_NAMESPACE
    kubectl rollout status deployment/cert-manager-cainjector -n $CERT_MANAGER_NAMESPACE
else
    echo "cert-manager already installed."
fi


# Install Kafka
echo "Installing Kafka..."
helm upgrade --install kafka oci://registry-1.docker.io/bitnamicharts/kafka -f values.yml

# Wait for Kafka to be ready
echo "Waiting for all Kafka brokers to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kafka --timeout=600s

# Install kafka-ui
helm repo add kafka-ui $KAFKA_UI_CHART
helm upgrade --install kafka-ui kafka-ui/kafka-ui --set envs.config.KAFKA_CLUSTERS_0_NAME=local --set envs.config.KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=kafka-controller-0.kafka-controller-headless.default.svc.cluster.local:9092

#Create config map
kubectl create configmap msk-configuration --from-literal=KAFKA_BROKERS='kafka-controller-0.kafka-controller-headless.default.svc.cluster.local:9092,kafka-controller-1.kafka-controller-headless.default.svc.cluster.local:9092,kafka-controller-2.kafka-controller-headless.default.svc.cluster.local:9092' --from-literal=KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS='kafka-controller-2.kafka-controller-headless.default.svc.cluster.local:9092'

# Install flink operator
#echo "Installing flink operator"
helm repo add flink-operator-repo $FLINK_OPERATOR_CHART
helm upgrade --install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator

#Deploy flink cluster
echo "Waiting for flink kubernetes operator to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=flink-kubernetes-operator --timeout=600s

#apply_flink_cluster $FLINK_CLUSTER_DEPLOYMENT 10 5
kubectl apply -f $FLINK_CLUSTER_DEPLOYMENT 

#echo "Waiting for flink cluster to be ready..."
wait_for_pods_by_label $NAMESPACE app=df-streaming-flinkcluster 60 10 30

