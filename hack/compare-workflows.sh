#!/bin/bash
# Script to compare against upstream version for differences

PROJECT_ROOT=$(cd $(dirname ${BASH_SOURCE})/..; pwd)
chart_root="${PROJECT_ROOT}/charts/argo-workflows"
upstream_version=v$(grep appVersion ${chart_root}/Chart.yaml | awk '{print $2}')

mytmpdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir')

helm template \
    --include-crds \
    --set controller.image.repository=quay.io/argoproj/workflow-controller \
    --set executor.image.repository=quay.io/argoproj/argoexec \
    --set server.image.repository=quay.io/argoproj/argocli \
    --set global.image.tag=${upstream_version} \
    --namespace argo ${chart_root} | grep -v imagePullPolicy > $mytmpdir/helm.yaml

echo """
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- helm.yaml
""" > $mytmpdir/kustomization.yaml

helm_out=$(kustomize build $mytmpdir)

upstream_out=$(
    curl -L --silent https://github.com/argoproj/argo-workflows/releases/download/${upstream_version}/install.yaml | \
    grep -v imagePullPolicy | \
    grep -v "This is an auto-generated file"
)

diff <(echo "$helm_out") <(echo "$upstream_out")
