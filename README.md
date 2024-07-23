# Flink Kafka local Deployment setup

This guide provides steps to set up a Kafka and Flink cluster on a local Kubernetes environment using a bash script.

## Prerequisites

- Docker
- Kubernetes (Minikube or Docker Desktop with Kubernetes enabled)
- kubectl
- Helm
- Artifactory Credentials 
- localDeployment.sh
- support.sh
- flink-cluster.yaml
- values.yaml

## Deployment

Run `flinkKafkaLocalDeployment.sh` script 

This will:
1. Install cert manager 
2. Start kafka brokers
3. Install flink-kubernetes-operator
4. start the flink cluster


Run `kubectl get deployments -A --watch` command and wait for all the deployments to be in the ready state.     


Once all the deployments are ready, to access:    
Kafka UI: `kubectl port-forward svc/kafka-ui 8082:80`,  
Flink UI: `kubectl port-forward svc/df-streaming-flinkcluster-rest 8081:8081`



