# Nebula Graph on Kind(NGonK)

This is a project inspired by [Carlos Santana](https://twitter.com/csantanapr)'s  [knative-kind](https://github.com/csantanapr/knative-kind), created with ❤️.

With the help of [KIND](https://kind.sigs.k8s.io/)(K8s IN Docker), KGonK helps us provision a dedicated ephemeral K8S cluster with all dependencies inside Docker, including:

- a dynamic storageClass provider
- all third parties of [nebula-operator](https://github.com/vesoft-inc/nebula-operator)
- Nebula-Operator Pods in namespace: `nebula-operator-system`
- the Nebula Graph Cluster Pods in default namespace

## How To Use

Just call the following one liner from your Linux Machine with at least 8 vCPUs:

```bash
curl -sL nebula-kind.siwei.io/install.sh | bash
```

Then you may see something like this:

![install_success](./images/install_success.webp)

## What's Next?

You could learn more about Nebula-Operator:

| Items                                            | URL                                                          |
| ------------------------------------------------ | ------------------------------------------------------------ |
| Repo                                             | https://github.com/vesoft-inc/nebula-operator                |
| Install Guide                                    | https://github.com/vesoft-inc/nebula-operator/blob/master/doc/user/install_guide.md |
| Sample Nebula Cluster CRD                        | https://github.com/vesoft-inc/nebula-operator/blob/master/config/samples/apps_v1alpha1_nebulacluster.yaml |
| Access Nebula Cluster created by Nebula Operator | https://github.com/vesoft-inc/nebula-operator/blob/master/doc/user/client_service.md |
| Docs of Nebula Graph                             | English: https://docs.nebula-graph.io<br />Chinese: https://docs.nebula-graph.com.cn |

