#!/bin/bash


echo "Starting removal of production application"
cd ./infrastructure/live/prod/k8s-addons
terragrunt destroy -auto-approve
if [ $? -eq 0 ]; then
  echo "prod app was removed"
else
  echo "app removal failure"
  exit 1
fi
cd ../../../../

echo "Starting production eks cluster destruction"
cd ./infrastructure/live/prod/eks
terragrunt destroy -auto-approve
if [ $? -eq 0 ]; then
  echo "prod eks was removed"
else
  echo "eks cluster destruction failure"
  exit 1
fi
cd ../../../../

echo "Terragrunt run for production application destruction completed successfully."