#!/bin/bash

echo "Starting production s3 bucket creation"
cd ./infrastructure/foundation/prod/s3
terragrunt init --upgrade
terragrunt apply -auto-approve
if [ $? -eq 0 ]; then
  echo "prod s3 bucket was created"
else
  echo "s3 bucket creation failure."
  exit 1
fi
cd ../../../../

echo "Starting production vpc creation"
cd ./infrastructure/foundation/prod/vpc
terragrunt init --upgrade
terragrunt apply -auto-approve
if [ $? -eq 0 ]; then
  echo "prod vpc was created"
else
  echo "vpc creation failure"
  exit 1
fi
cd ../../../../

echo "Starting production rds instance creation"
cd ./infrastructure/foundation/prod/rds
terragrunt init --upgrade
terragrunt apply -auto-approve
if [ $? -eq 0 ]; then
  echo "prod rds was created"
else
  echo "rds creation failure"
  exit 1
fi
cd ../../../../

echo "Starting production eks cluster creation"
cd ./infrastructure/live/prod/eks
terragrunt init --upgrade
terragrunt apply -auto-approve
if [ $? -eq 0 ]; then
  echo "prod eks was created"
else
  echo "eks cluster creation failure"
  exit 1
fi
cd ../../../../

echo "Starting instalation of production application"
cd ./infrastructure/live/prod/k8s-addons
terragrunt init --upgrade
terragrunt apply -auto-approve
if [ $? -eq 0 ]; then
  echo "prod app was created"
else
  echo "app installation failure"
  exit 1
fi
cd ../../../../

aws eks update-kubeconfig --region us-east-1 --name prod-eks

echo "Terragrunt run for production environment completed successfully."
echo "Connect at this address:"
echo $(kubectl get ingress nginx-controller-alb -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')