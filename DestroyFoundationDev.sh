#!/bin/bash

echo "Starting dev rds instance destruction"
cd ./infrastructure/foundation/dev/rds
terragrunt destroy -auto-approve
if [ $? -eq 0 ]; then
  echo "dev rds was removed"
else
  echo "rds cremoval failure"
  exit 1
fi
cd ../../../../

echo "Starting dev vpc destruction"
cd ./infrastructure/foundation/dev/vpc
terragrunt destroy -auto-approve
if [ $? -eq 0 ]; then
  echo "dev vpc was removed"
else
  echo "vpc removal failure"
  exit 1
fi
cd ../../../../

echo "Starting dev s3 bucket destruction"
cd ./infrastructure/foundation/dev/s3
terragrunt destroy -auto-approve
if [ $? -eq 0 ]; then
  echo "dev s3 bucket was removed"
else
  echo "s3 bucket cremoval failure."
  exit 1
fi
cd ../../../../

echo "Terragrunt run for dev environment foundation destruction completed successfully."