#!/bin/bash

echo "Starting dev s3 bucket creation"
cd ./infrastructure/foundation/dev/s3
terragrunt init --upgrade
terragrunt apply -auto-approve
if [ $? -eq 0 ]; then
  echo "dev s3 bucket was created"
else
  echo "s3 bucket creation failure."
  exit 1
fi
cd ../../../../

echo "Starting dev vpc creation"
cd ./infrastructure/foundation/dev/vpc
terragrunt init --upgrade
terragrunt apply -auto-approve
if [ $? -eq 0 ]; then
  echo "dev vpc was created"
else
  echo "vpc creation failure"
  exit 1
fi
cd ../../../../

echo "Starting dev rds instance creation"
cd ./infrastructure/foundation/dev/rds
terragrunt init --upgrade
terragrunt apply -auto-approve
if [ $? -eq 0 ]; then
  echo "dev rds was created"
else
  echo "rds creation failure"
  exit 1
fi
cd ../../../../

echo "Starting dev eks cluster creation"
cd ./infrastructure/live/dev/eks
terragrunt init --upgrade
terragrunt apply -auto-approve
if [ $? -eq 0 ]; then
  echo "dev eks was created"
else
  echo "eks cluster creation failure"
  exit 1
fi
cd ../../../../

echo "Starting instalation of dev application"
cd ./infrastructure/live/dev/k8s-addons
terragrunt init --upgrade
terragrunt apply -auto-approve
if [ $? -eq 0 ]; then
  echo "dev app was created"
else
  echo "app installation failure"
  exit 1
fi
cd ../../../../

aws eks update-kubeconfig --region us-east-1 --name dev-eks

echo "Terragrunt run for dev environment completed successfully."
echo "Connect at this address:"
echo $(kubectl get ingress nginx-controller-alb -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')