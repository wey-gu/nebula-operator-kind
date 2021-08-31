# Nebula Graph on Kind(NGonK)

This is a project inspired by [Carlos Santana](https://twitter.com/csantanapr)'s  [knative-kind](https://github.com/csantanapr/knative-kind), created with ❤️.

With the help of [KIND](https://kind.sigs.k8s.io/)(K8s IN Docker), KGonK helps us provision a dedicated ephemeral K8S cluster with all dependencies inside Docker, including:

- A dynamic storageClass provider
- All third party dependencies of [nebula-operator](https://github.com/vesoft-inc/nebula-operator)
- Nebula-Operator Pods in namespace: `nebula-operator-system`
- The Nebula Graph Cluster Pods in default namespace
- A nodePort service exposing `0.0.0.0:30000` of the host mapped to `graphd:9669`

## How To Use

Just call the following one liner from your Linux Machine with at least 4 vCPUs:

```bash
curl -sL nebula-kind.siwei.io/install.sh | bash
```

Then you may see something like this:

![install_success](./images/install_success.webp)

## What's Next?

Access nebula graph console with this command:
```bash
~/.nebula-kind/bin/console -u root -p password --address=127.0.0.1 --port=30000
```

You could learn more about Nebula-Operator:

| Items                                            | URL                                                          |
| ------------------------------------------------ | ------------------------------------------------------------ |
| Repo                                             | https://github.com/vesoft-inc/nebula-operator                |
| Install Guide                                    | https://github.com/vesoft-inc/nebula-operator/blob/master/doc/user/install_guide.md |
| Sample Nebula Cluster CRD                        | https://github.com/vesoft-inc/nebula-operator/blob/master/config/samples/apps_v1alpha1_nebulacluster.yaml |
| Access Nebula Cluster created by Nebula Operator | https://github.com/vesoft-inc/nebula-operator/blob/master/doc/user/client_service.md |
| Docs of Nebula Graph                             | English: https://docs.nebula-graph.io<br />Chinese: https://docs.nebula-graph.com.cn |


## Troubleshooting

### Ensuring docker Permission Failed
You may encounter this error in case docker was not installed before our installation, you could just follow instructions below to run `newgrp docker` and then rerun the installation, it will pass in next go.
```bash
ℹ️    Ensuring Linux Docker Permission

 ❌   Ensuring docker Permission Failed, please try:
 option 0: execute this command and retry:
 $ newgrp docker
 option 1: relogin current shell session and retry install.sh
```

### Some of the K8S resource is not ready(pods)

```bash
ℹ️    Waiting for <foo bar> pods to be ready...
```

There could be different causes:

You could check the reason from another terminal:

```bash
kubectl get pods --all-namespaces
kubectl describe pods <pod_name> -n <namespace_name>
```

- Docker hub pull limit hit
In this case, you can refer to https://medium.com/rossum/how-to-overcome-docker-hub-pull-limits-in-a-kubernetes-cluster-382f317accc1.

If you are in China, [this](https://gist.github.com/y0ngb1n/7e8f16af3242c7815e7ca2f0833d3ea6) may help.

- CPU resource is not enough
Please assign more CPU/RAM to your docker or host machine.
