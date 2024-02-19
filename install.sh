#!/usr/bin/env bash
set -e

# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,

# Usage: install.sh

# Check Platform & Distribution

function logger_info {
    echo
    echo " ℹ️   " $1
}

function logger_warn {
    echo
    echo " ⚠️   " $1 1>&2
}

function logger_error {
    echo
    echo -e " ❌  " $1 1>&2
    echo "      Exiting, Stack Trace: ${executing_function-${FUNCNAME[*]}}"
    cd $CURRENT_PATH
    print_footer_error
    exit 1
}

function logger_ok {
    echo " ✔️   " $1
}

function execute_step {
    executing_function=$1
    $1 && logger_ok "$1 Finished" || logger_error "Failed in Step: $(echo ${executing_function//_/ })"
}

function print_banner {
    echo '┌───────────────────────────────────────────────────────────────┐'
    echo '│ 🌌 Nebula-K8S in Docker is on the way...                      │'
    echo '└───────────────────────────────────────────────────────────────┘'
}

function get_platform {
    case $(uname -ms) in
        "Darwin x86_64") platform="x86_64-darwin" ;;
        "Darwin arm64")  platform="aarch64-darwin" ;;
        "Linux x86_64")  platform="x86_64-linux" ;;
        *)               platform="unknown-platform" ;;
    esac
    echo $platform
}

function is_linux {
    if [[ $(uname -s) == Linux ]]; then
        true
    else
        false
    fi
}

function is_mac {
    if [[ $(uname -s) == Darwin ]]; then
        true
    else
        false
    fi
}

function verify_sudo_permission {
    logger_info "Verifying user's sudo Permission..."
    sudo true
}

function get_distribution {
    echo "$(source /etc/os-release && echo "$ID")"
}

# Detect Network Env

function nc_get_google_com {
    echo 2> /dev/null -n "GET / HTTP/1.0\r\n" | nc -v google.com 80 2>&1 | grep -q "http] succeeded" && echo "OK" || echo "NOK"
}

function cat_get_google_com {
    cat 2>/dev/null < /dev/null > /dev/tcp/google.com/80 && echo "OK" || echo "NOK"
}

function is_CN_NETWORK {
    case $PLATFORM in
        "x86_64-darwin"|"aarch64-darwin") internet_result=$(nc_get_google_com) ;;
        "x86_64-linux") internet_result=$(cat_get_google_com) ;;
    esac
    if [ $internet_result == "OK" ]; then
        false
    else
        true
    fi
}

# Install Dependencies(docker, Package Manager) with Network Env Awareness

function utility_exists {
    which $1 1>/dev/null 2>/dev/null && true || false
}

function install_package_ubuntu {
    sudo apt-get update -y
    sudo apt-get install -y $1
}

function install_package_centos {
    sudo yum -y update
    sudo yum -y install $1
}

function install_homebrew {
    if is_CN_NETWORK; then
        # https://mirrors.tuna.tsinghua.edu.cn/help/homebrew/
        BREW_TYPE="homebrew"
        HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
        HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/${BREW_TYPE}-core.git"
        HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/${BREW_TYPE}-bottles"
    fi
    logger_info "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

function install_package_mac {
    if ! utility_exists "brew"; then
        install_homebrew
    fi
    brew install $1
}

function install_package {
    case $PLATFORM in
        *arwin*) install_package_mac $1;;
        *inux*)  install_package_$(get_distribution) $1;;
    esac
}

function install_docker {
    # For both Linux and Darwin cases, CN network was considerred
    logger_info "Starting Instlation of Docker"
    case $PLATFORM in
        *inux*)  utility_exists "wget" || install_package "wget" && sudo sh -c "$(wget https://get.docker.com -O -)" ;;
        *arwin*) install_package "docker" ;;
    esac
}

function waiting_for_docker_engine_up {
    logger_info "Waiting for Docker Engine to be up..."

    local max_attempts=${MAX_ATTEMPTS-6}
    local timer=${INIT_TIMER-4}
    local attempt=1

    while [[ $attempt < $max_attempts ]]
    do
        status=$(sudo docker ps 1>/dev/null 2>/dev/null && echo OK||echo NOK)
        if [[ "$status" == "OK" ]]; then
            logger_ok "docker engine is up."
            break
        fi
        logger_info "Docker Engine Check Attempt: ${attempt-0} Failed, Retrying in $timer Seconds..."
        sleep $timer
        attempt=$(( attempt + 1 ))
        timer=$(( timer * 2 ))
    done

    if [[ "$status" != "OK" ]]; then
        logger_error "Failed to start Docker Engine, we are sorry about this :("
    fi
}

function start_docker {
    case $PLATFORM in
        *inux*)  sudo systemctl start docker ;;
        *arwin*) open -a Docker ;;
    esac
    waiting_for_docker_engine_up
}

function restart_docker {
    case $PLATFORM in
        *inux*)  sudo systemctl daemon-reload && sudo systemctl restart docker ;;
        *arwin*) osascript -e 'quit app "Docker"' && open -a Docker ;;
    esac
    waiting_for_docker_engine_up
}

function configure_docker_cn_mirror {
    # FIXME: let's override it as it's assumed docker was installed by this script, while it's good to actually edit the json file
    case $PLATFORM in
        *inux*)  DOCKER_CONF_PATH="/etc/docker" ;;
        *arwin*) DOCKER_CONF_PATH="$HOME/.docker" ;;
    esac
    sudo bash -c "cat > ${DOCKER_CONF_PATH}/daemon.json" << EOF
{
  "registry-mirrors": [
    "https://hub-mirror.c.163.com"
  ]
}
EOF
}

function ensure_docker_permission {
    logger_info "Ensuring Linux Docker Permission"
    if is_linux; then
        sudo groupadd docker --force || \
            logger_error "failed during: groupadd docker"
        sudo usermod -aG docker $USER || \
            logger_error "failed during: sudo usermod -aG docker $USER"
        newgrp docker <<EOF || \
            logger_error "failed during: newgrp docker"
EOF
    fi
    docker ps 1>/dev/null 2>/dev/null || \
        logger_error "Ensuring docker Permission Failed, please try: \n \
            option 0: execute this command and retry:\n $ newgrp docker\n \
            option 1: relogin current shell session and retry installation \n"
}

function install_kubectl {
    if is_mac; then
        install_package_mac "kubectl"
    else
        cd $WOKRING_PATH
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl > /dev/null || logger_error "Failed to install kubectl"
    fi
}

function install_nebula_console {
    cd $WOKRING_PATH/bin/
    if is_mac; then
        curl -L "https://github.com/vesoft-inc/nebula-console/releases/download/v3.2.0/nebula-console-darwin-amd64-v3.2.0" -o console
    else
        curl -L "https://github.com/vesoft-inc/nebula-console/releases/download/v3.2.0/nebula-console-linux-amd64-v3.2.0" -o console
    fi
    chmod +x console
}

function create_node_port {
    cd $WOKRING_PATH/bin/
    cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/cluster: nebula
    app.kubernetes.io/component: graphd
    app.kubernetes.io/managed-by: nebula-operator
    app.kubernetes.io/name: nebula-graph
  name: nebula-graphd-svc-nodeport
  namespace: default
spec:
  externalTrafficPolicy: Local
  ports:
  - name: thrift
    port: 9669
    protocol: TCP
    targetPort: 9669
    nodePort: 30000
  - name: http
    port: 19669
    protocol: TCP
    targetPort: 19669
    nodePort: 30001
  selector:
    app.kubernetes.io/cluster: nebula
    app.kubernetes.io/component: graphd
    app.kubernetes.io/managed-by: nebula-operator
    app.kubernetes.io/name: nebula-graph
  type: NodePort
EOF
}

function ensure_dependencies {
    if ! utility_exists "git"; then
        install_package "git"
    fi
    if ! utility_exists "docker"; then
        install_docker
        if is_CN_NETWORK; then
            configure_docker_cn_mirror
            restart_docker
        fi
    else
        start_docker
    fi
    ensure_docker_permission
    # kubectl
    if ! utility_exists "kubectl"; then
        install_kubectl
    fi
}

# Check Ports States

function check_ports_availability {
    logger_info "Checking Ports Availability"
    # TBD
}

function download_kind {
    # For both Linux and Darwin cases, CN network was considerred
    logger_info "Starting Instlation of Docker"
    case $PLATFORM in
        *inux*)  utility_exists "curl" || install_package "curl" && curl -Lo $WOKRING_PATH/bin/kind https://kind.sigs.k8s.io/dl/v0.11.0/kind-linux-amd64 && chmod +x $WOKRING_PATH/bin/kind ;;
        *arwin*) install_package "kind" ;;
    esac
}

function install_kind {
    cd $WOKRING_PATH
    if [ ! -d "$WOKRING_PATH/bin" ]; then
        mkdir -p $WOKRING_PATH/bin
    fi
    download_kind 1>/dev/null 2>/dev/null
    cat <<EOF | $WOKRING_PATH/bin/kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
featureGates:
  "RemoveSelfLink": false
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
  - containerPort: 30001
    hostPort: 30001
EOF
    logger_info "Waiting for k8s cluster to be ready..."
    sleep 10
    until kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n kube-system > /dev/null
    do
       kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n kube-system > /dev/null
    done
    kubectl cluster-info --context kind-kind
}


function install_nebula_operator {
    cd $WOKRING_PATH
    # install operator dep
    kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.yaml
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    export PATH=/usr/local/bin:$PATH

    helm repo add openkruise https://openkruise.github.io/charts/
    helm install --set manager.resources.requests.cpu=1m kruise openkruise/kruise --version 1.2.0
    if [ ! -d "$WOKRING_PATH/nebula-operator" ]; then
        git clone https://github.com/vesoft-inc/nebula-operator.git
    else
        logger_warn "$WOKRING_PATH/nebula-operator already exists, existing repo will be reused"
    fi
    kubectl create namespace nebula-operator-system > /dev/null
    cd $WOKRING_PATH/nebula-operator
    helm repo add nebula-operator https://vesoft-inc.github.io/nebula-operator/charts > /dev/null || logger_error "Failed to add helm repo: nebula-operator"
    helm repo update > /dev/null || logger_error "Failed to update helm repo"

    sleep 10
    logger_info "Waiting for kruise-system pods to be ready..."
    until kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' --all-namespaces > /dev/null
    do
       kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' --all-namespaces > /dev/null
    done

    helm install --set controllerManager.resources.requests.cpu=1m nebula-operator nebula-operator/nebula-operator --namespace=nebula-operator-system --version="1.7.6" > /dev/null || logger_error "Failed to install helm chart nebula-operator"

    sleep 20
    logger_info "Waiting for nebula-operator pods to be ready..."
    until kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n nebula-operator-system > /dev/null
    do
       kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n nebula-operator-system > /dev/null
    done
}

function install_hostpath_provisioner {
    cd $WOKRING_PATH
    sed -i 's/500m/1m/g' nebula-operator/config/samples/apps_v1alpha1_nebulacluster.yaml
    sed -i 's/500Mi/20Mi/g' nebula-operator/config/samples/apps_v1alpha1_nebulacluster.yaml
    sed -i 's/gp2/hostpath/g' nebula-operator/config/samples/apps_v1alpha1_nebulacluster.yaml
    helm repo add rimusz https://charts.rimusz.net
    helm repo update
    helm upgrade --install hostpath-provisioner --namespace kube-system rimusz/hostpath-provisioner
    sleep 5
    logger_info "Waiting for hostpath-provisioner pods to be ready..."
    until kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n kube-system > /dev/null
    do
       kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n kube-system > /dev/null
    done
}

function create_nebula_cluster {
    cd $WOKRING_PATH
    kubectl create -f nebula-operator/config/samples/apps_v1alpha1_nebulacluster.yaml
    sleep 45
    logger_info "Waiting for nebula cluster pods to be ready..."
    until kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' > /dev/null
    do
       kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' > /dev/null
    done
}

# Create Uninstall Script

function create_uninstall_script {
    sudo bash -c "WOKRING_PATH=$WOKRING_PATH;cat > $WOKRING_PATH/uninstall.sh" << EOF
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,

# Usage: uninstall.sh

echo " ℹ️   Cleaning Up Files under $WOKRING_PATH..."
kubectl delete ns kruise-system nebula-operator-system cert-manager 2>/dev/null
$WOKRING_PATH/bin/kind delete cluster --name kind 2>/dev/null
helm uninstall nebula-operator -n nebula-operator-system 2>/dev/null
sudo rm -fr $WOKRING_PATH $WOKRING_PATH/nebula-operator 2>/dev/null
echo "┌────────────────────────────────────────┐"
echo "│ 🌌 Nebula-Kind Uninstalled             │"
echo "└────────────────────────────────────────┘"
EOF
    sudo chmod +x $WOKRING_PATH/uninstall.sh
}

function print_footer {

    echo "┌────────────────────────────────────────┐"
    echo "│ 🌌 Nebula-Kind Playground is Up now!   │"
    echo "├────────────────────────────────────────┤"
    echo "│                                        │"
    echo "│ 🎉 Congrats!                           │"
    echo "│    $ cd ~/.nebula-kind                 │"
    echo "│                                        │"
    echo "│ 🔥 Or access via Nebula Console:       │"
    echo "│    $ ~/.nebula-kind/bin/console        │"
    echo "│                                        │"
    echo "│    To remove the playground:           │"
    echo "│    $ ~/.nebula-kind/uninstall.sh       │"
    echo "│                                        │"
    echo "│ 🚀 Have Fun!                           │"
    echo "│                                        │"
    echo "└────────────────────────────────────────┘"
    echo
    echo
    echo "┌──────────────────────────────────────────────────────────────────────────────────────┐"
    echo "│ 🔥 You can access its console as with following command                              │"
    echo "├──────────────────────────────────────────────────────────────────────────────────────┤"
    echo "│~/.nebula-kind/bin/console -u root -p password --address=127.0.0.1 --port=30000       │"
    echo "└──────────────────────────────────────────────────────────────────────────────────────┘"
}

function print_footer_error {

    echo "┌────────────────────────────────────────┐"
    echo "│ 🌌 Nebula-Kind run into issues 😢      │"
    echo "├────────────────────────────────────────┤"
    echo "│                                        │"
    echo "│ 🎉 To cleanup before retrying :        │"
    echo "│    $ ~/.nebula-kind/uninstall.sh       │"
    echo "│                                        │"
    echo "└────────────────────────────────────────┘"

}

function main {
    print_banner

    CURRENT_PATH="$pwd"
    WOKRING_PATH="$HOME/.nebula-kind"
    mkdir -p $WOKRING_PATH && cd $WOKRING_PATH
    PLATFORM=$(get_platform)
    CN_NETWORK=false
    if is_CN_NETWORK; then
        CN_NETWORK=true
    fi

    execute_step verify_sudo_permission
    logger_info "Preparing Nebula-Kind Uninstall Script..."
    execute_step create_uninstall_script

    logger_info "Ensuring Depedencies..."
    execute_step ensure_dependencies

    logger_info "Install K8s in Docker..."
    execute_step install_kind

    logger_info "Boostraping Nebula Graph with Nebula-Operator"
    execute_step install_nebula_operator
    execute_step install_hostpath_provisioner
    execute_step create_nebula_cluster
    execute_step install_nebula_console
    execute_step create_node_port

    print_footer
}

main
