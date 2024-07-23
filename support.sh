# Function to wait for pods with a specific label to be in the Running state
wait_for_pods_by_label() {
  local namespace=$1
  local label=$2
  local retries=$3
  local delay=$4
  local wait_if_none=$5

  echo "Waiting for pods with label $label to be in Running state in namespace $namespace..."

  for i in $(seq 1 $retries); do
    pods=$(kubectl get pods -n $namespace -l $label -o jsonpath='{.items[*].metadata.name}')
    if [ -z "$pods" ]; then
      echo "No pods found with label $label in namespace $namespace. Waiting for $wait_if_none seconds..."
      sleep $wait_if_none
      continue
    fi

    all_running=true
    for pod in $pods; do
      pod_status=$(kubectl get pod $pod -n $namespace -o jsonpath='{.status.phase}')
      if [ "$pod_status" != "Running" ]; then
        all_running=false
        break
      fi
    done

    if [ "$all_running" = true ]; then
      echo "All pods with label $label are Running."
      return 0
    fi
    echo "Waiting for pods... attempt $i/$retries"
    sleep $delay
  done

  echo "Pods with label $label did not reach Running state in time."
  return 1
}

apply_flink_cluster() {
  local ymlFile=$1
  local retries=$2
  local delay=$3

  for i in $(seq 1 $retries); do
    echo "Attempting to apply Flink cluster YAML file (attempt $i/$retries)..."
    kubectl apply -f $ymlFile && return 0
    echo "Failed to apply Flink cluster YAML file. Retrying in $delay seconds..."
    sleep $delay
  done

  echo "Failed to apply Flink cluster YAML file after $retries attempts."
  return 1
}