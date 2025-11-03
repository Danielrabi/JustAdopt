#!/bin/bash

echo "Starting production rds instance destruction"
cd ./infrastructure/foundation/prod/rds
terragrunt destroy -auto-approve
if [ $? -eq 0 ]; then
  echo "prod rds was removed"
else
  echo "rds cremoval failure"
  exit 1
fi
cd ../../../../

echo "Starting production vpc destruction"
cd ./infrastructure/foundation/prod/vpc
terragrunt destroy -auto-approve
if [ $? -eq 0 ]; then
  echo "prod vpc was removed"
else
  echo "vpc removal failure"
  exit 1
fi
cd ../../../../

echo "Starting production s3 bucket destruction"
cd ./infrastructure/foundation/prod/s3
terragrunt destroy -auto-approve
if [ $? -eq 0 ]; then
  echo "prod s3 bucket was removed"
else
  echo "s3 bucket cremoval failure."
  exit 1
fi
cd ../../../../

echo "Terragrunt run for production environment foundation destruction completed successfully."