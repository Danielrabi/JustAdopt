# Cloud Infrastructure Learning Project

This project was created by Daniel Rabinovich as part of a learning journey into cloud automation and DevOps tools.

It demonstrates a complete pipeline using Terraform, Terragrunt, Helm, and ArgoCD to manage and deploy cloud environments.

## Overview

* **Terraform** is used to provision the cloud infrastructure.
* **Terragrunt** helps structure and manage multiple environments — in this case, development and production.
* **ArgoCD** is deployed on the Terraform-created Kubernetes clusters. It continuously monitors this GitHub repository and updates deployments automatically whenever changes are pushed.
* The `helm` branch contains the Helm chart used for deployments.
* The `images` branch contains a custom application, along with a GitHub Actions workflow that automatically builds, tags, and pushes Docker images to Docker Hub on every push.

## Requirements

Before running the project, make sure the following tools are installed:

* AWS CLI
* Terraform
* Terragrunt

## Usage

1.  Log in to the AWS CLI:
    ```sh
    aws configure
    ```

2.  To deploy the production environment:
    ```sh
    ./Run.sh
    ```

3.  To deploy the development environment:
    ```sh
    ./RunDev.sh
    ```

## Cleanup / Destruction

To tear down the environments, you will need to run the 2 staged of scripts for each environment, one destroys the "app" (compute) the second destroys the foundation
If foundation is kept data is retained between deployments

> **Disclaimer: Interactive Destruction**
> Please be aware that the destroy process is interactive. Because Terragrunt modules are depandent on each other, you will be prompted to manually type `y` to approve the destruction for *each module*. This requires active monitoring ("babysitting") of the terminal to confirm each prompt as it appears.

1.  To destroy the production cluster:
    ```sh
    ./DestroyApp.sh
    ```

2.  To destroy the development cluster:
    ```sh
    ./DestroyAppDev.sh
    ```

3.  To destroy the production foundation (all data will be lost):
    ```sh
    ./DestroyFoundation.sh
    ```

4.  To destroy the development foundation (all data will be lost):
    ```sh
    ./DestroyFoundationDev.sh
    ```