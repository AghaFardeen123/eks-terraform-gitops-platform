# EKS + Terraform + GitOps (ArgoCD) Platform

A production-shaped starting point for running workloads on Amazon EKS: Terraform
provisions the VPC, cluster, node group, and IRSA roles; ArgoCD then takes over
application delivery using an app-of-apps GitOps pattern, so `main` in this repo
is the single source of truth for what's running in the cluster.

## What's here

- **`terraform/`** — VPC (`terraform-aws-modules/vpc`), EKS cluster and managed
  node group (`terraform-aws-modules/eks`), and an IRSA role for the AWS Load
  Balancer Controller (`terraform-aws-modules/iam//modules/iam-role-for-service-accounts-eks`).
  All resources are tagged consistently via `default_tags` + `local.common_tags`.
- **`gitops/bootstrap/`** — the `argocd` namespace ArgoCD itself is installed into.
- **`gitops/app-of-apps/`** — a root ArgoCD `Application` that watches
  `gitops/apps/` and auto-syncs (prune + self-heal) anything added there.
- **`gitops/apps/sample-app/`** — a small demo Deployment/Service/HPA managed
  with Kustomize, standing in for a real workload.

## Why this shape

- **Terraform owns infrastructure, ArgoCD owns applications.** Nobody runs
  `kubectl apply` by hand against the cluster — new workloads are added by
  committing a folder under `gitops/apps/` and letting the root Application
  pick it up.
- **IRSA over static credentials.** The Load Balancer Controller gets scoped,
  short-lived AWS permissions through its Kubernetes service account instead
  of a long-lived IAM user.
- **Right-sized node group.** `t3.medium` x 1-4 with cluster-driven
  autoscaling bounds instead of an arbitrarily large fixed pool.

## CI

Two independent GitHub Actions jobs run on every push/PR:

- **`terraform`** — `terraform fmt -check`, `terraform validate`, `tflint`
  (with the AWS ruleset plugin), and `tfsec` against the `terraform/` stack.
- **`kubernetes-manifests`** — `kubeconform` schema-validates every plain
  Kubernetes manifest and the ArgoCD `Application` CRDs, and `kustomize build`
  confirms the sample app's Kustomization resolves cleanly.

## Deploying

```bash
cd terraform
terraform init
terraform apply

aws eks update-kubeconfig --region <region> --name gitops-demo

kubectl apply -f gitops/bootstrap/namespace.yaml
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f gitops/app-of-apps/root-application.yaml
```

From that point on, ArgoCD reconciles `gitops/apps/` continuously — adding a
new app is a Git commit, not a cluster command.

## Cleanup

```bash
kubectl delete -f gitops/app-of-apps/root-application.yaml
cd terraform && terraform destroy
```
