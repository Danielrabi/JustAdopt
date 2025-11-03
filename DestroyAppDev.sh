#!/bin/bash


echo "Starting removal of dev application"
cd ./infrastructure/live/dev/k8s-addons
terragrunt destroy -auto-approve
if [ $? -eq 0 ]; then
  echo "dev app was removed"
else
  echo "app removal failure"
  exit 1
fi
cd ../../../../

echo "Starting dev eks cluster destruction"
cd ./infrastructure/live/dev/eks
terragrunt destroy -auto-approve
if [ $? -eq 0 ]; then
  echo "dev eks was removed"
else
  echo "eks cluster destruction failure"
  exit 1
fi
cd ../../../../

echo "Terragrunt run for dev application destruction completed successfully."