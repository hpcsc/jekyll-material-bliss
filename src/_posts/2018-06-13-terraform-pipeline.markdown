---
layout: post
title:  "Terraform Pipeline"
date:   2018-06-13 09:00:00 +0800
type: post
categories: devops, deployment
tags: devops deployment terraform packer gocd
---

## Introduction

In my current project, I have a chance to use Terraform and Packer to automate the process of setting up a new testing environment in AWS. However I always feel something is not right. Terraform is a tool that promotes infrastructure as code, immutable infrastructure, but what we do in this project doesn't align to those principles:

- after the servers are created using Terraform, they are maintained manually (.i.e. software is installed/updated by ssh-ing to the servers and updating directly there). After a while, server configuration is drifting away from Terraform code (an issue known as configuration drift)
- Terraform code is version controlled, however it's not truly treated as `code`, i.e. there's no testing, no integration, no build pipeline to ensure new commit doesn't break any server configuration, no automated application of Terraform code to actual environments

After digging through several online resources ([Using Pipelines to Manage Environments with Infrastructure as Code](https://medium.com/@kief/https-medium-com-kief-using-pipelines-to-manage-environments-with-infrastructure-as-code-b37285a1cbf5)) and book ([Terraform: Up and Running](https://www.amazon.com/Terraform-Running-Writing-Infrastructure-Code/dp/1491977086/ref=sr_1_1?ie=UTF8&qid=1528855626&sr=8-1&keywords=terraform+up+and+running)), I have a better understanding of how to structure a build pipeline to automate Terraform build and deploy process. Although those resources give me an initial idea, they lack actual code demonstration. So I'm creating a pipeline myself to test my knowledge, and to create a sample for future reference. I'm going to walk through the main points of the pipeline below.

## Tools

For CI, I use GoCD. Nothing specifically from the pipeline requires GoCD and the same concepts can be applied to other CI tools.

For the setup of GoCD in local using docker-compose, refer to my previous article on [sample GoCD pipeline](/posts/a-sample-gocd-pipeline). I'm using the same setup (.i.e. one GoCD server, 3 agents). Additionally, I install a few more things in the agents:

- Terraform
- Packer
- AWS CLI
- jq (for json processing)

## Pipeline Design

Here's an overview of the pipeline:

![]({% asset_path 2018-06-13-terraform-pipeline %} "Terraform Pipeline")

The purpose of this pipeline is to setup 2 environments (Staging and Production) using Terraform. Each environment has 1 EC2 instance, with Nginx installed and displays a custom HTML page.

There are 3 repositories:

- `terraform-pipeline-packer`: contains Packer code to generate an AMI based on Ubuntu, with Nginx installed.
- `terraform-pipeline`: contains Terraform code to spin up an EC2 instance using AMI provided by previous Packer build
- `terraform-pipeline-config`: contains `tfvars` files which are configuration for Terraform that are specific to each environment

Separation of Terraform infrastructure definition and Terraform environment-specific configuration is on purpose. This separation closely resemble how we normally separate code and configuration (passed in through environment variables, property files, etc). In normal build pipeline, code is only built/compiled once and deployed to different environments with different configurations. Similarly, in this pipeline, Terraform infrastructure definition is processed once, stored in S3 and applied to different environments using different Terraform configurations.

As seen from the diagram above, the pipeline goes through 4 stages (4 pipelines in GoCD term): PackerCommit -> TerraformCommit -> TerraformStaging -> TerraformProduction

This is how they look in GoCD overview page:

![]({% asset_path 2018-06-13-terraform-gocd-overview %} "GoCD Overview")

#### PackerCommit Stage

Here's how the Packer builder is defined:

```
  "variables": {
    "build_label": "{{ env `BUILD_LABEL`}}"
  },
  "builders": [
    {
      "type": "amazon-ebs",
      "region": "ap-southeast-1",
      "source_ami": "ami-81cefcfd",
      "instance_type": "t2.micro",
      "ssh_username": "ubuntu",
      "ami_name": "nginx-terraform-pipeline-{{user `build_label`}}"
    }
  ]
```

It takes in an environment variable BUILD_LABEL (to be passed in by GoCD) and uses that to tag AMI name. Other settings are just standard EC2 settings

The Packer uses shell and file provisioners to install nginx and copies custom index.html (stored in the same repository with Packer file) over:

```
  "provisioners": [
    {
      "type": "shell",
      "inline": [
        "sudo apt-get update",
        "sudo apt-get install -y nginx"
      ]
    },
    {
      "type": "file",
      "source": "index.html",
      "destination": "/tmp/nginx-index.html"
    },
    {
      "type": "shell",
      "inline": [ "sudo mv -f /tmp/nginx-index.html /var/www/html/index.html" ]
    }
  ]
```

The reason I need to copy file to `/tmp` first before moving it to `/var/www` is because `/var/www` requires sudo priviledge and I can't provide that in file provisioner

In GoCD, the PackerCommit stage contains only 2 simple tasks:

- Validate: calling to `packer validate` to validate the syntax of Packer definition file
- Build: calling to `packer build` to build an AMI, passing in GoCD pipeline label. After this step is successful, an AMI with label `nginx-terraform-pipeline-{LABEL}` is created and stored in AWS

Successful build of Packer image also triggers the next stage: `TerraformCommit`

#### TerraformCommit Stage

First I'm going to walk through Terraform files in `terraform-pipeline` repository.

The main Terraform file (`modules/nginx/main.tf`) defines an EC2 instance:

```
resource "aws_instance" "nginx_server" {
  ami                    = "${data.aws_ami.nginx_ami.id}"
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.nginx_security_group.id}"]
  key_name               = "hpcsc-terraform"

  tags {
    Name      = "terraform-example-${var.server_name}"
    CreatedBy = "Terraform"
  }
}
```

This definition uses a few security groups defined in `modules/nginx/security-group.tf` that allow incoming port 80, 22, any outgoing connection. It also uses Terraform data source to dynamically look up AMI created by Packer in previous stage. This is definition of the data source:

```
data "aws_ami" "nginx_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["nginx-terraform-pipeline-${var.packer_build_number}"]
  }

  owners = ["self"]
}
```

This data source simply filters AWS AMI for the most recent AMI created by current AWS account, with the name following pattern `nginx-terraform-pipeline-{BUILD_NUMBER}`. The `packer_build_number` variable is passed in by GoCD

We also use S3 to store Terraform state of each environment:

```
terraform {
  backend "s3" {
    bucket         = "terraform-pipeline-state"
    region         = "ap-southeast-1"
    dynamodb_table = "tf-state-lock"
  }
}
```

This tells Terraform to store state in S3 bucket `terraform-pipeline-state`, use dynamodb table `tf-state-lock` to lock when there's multiple concurrent edit. This definition ignores `key` property (which is the name of the state file in S3 bucket) on purpose. The `key` property is going to be passed in by each environment-specific pipeline later.

The TerraformCommit pipeline consists of a few tasks:

- Validate: calling to `terraform validate` to validate syntax of Terraform files
- Test: this is just a simple `echo` at the moment. In a real world scenario, I would imagine a few things can be done in this task:
  - spin up an actual EC2 instance using provided Terraform files to quickly test that the files work. The instance can be destroyed immediately after verification
  - or use some Terraform specific testing tools like `kitchen-terraform` to test. I don't have enough exposure to these tools to comment.
- Sync to S3: after Test step, we should have sufficient confidence that the Terraform files work. This step will copy those Terraform files to S3. We are treating the Terraform files as artifacts produced by the build process and need to be stored in some artifact repository. The same files can be used in subsequent stages. This will ensure that the same files are "promoted" through different environments. The artifacts are stored in S3 in different folders with the GoCD pipeline label (.e.g. 8.24) as name.

#### TerraformStaging stage

First is the organization of `terraform-pipeline-config` repository:

![]({% asset_path 2018-06-13-terraform-config-organization %} "terraform-pipeline-config Organization")

The files are stored according to the environments that they belong to. Each environment has 2 files:

- `terraform.tfvars`: this contains environment-specific values for variables defined in Terraform files, e.g. for staging: `server_name = "Staging"`
- `backend.tfvars`: this contains the key in S3 to store Terraform state

This TerraformStaging stage does a few things:

- Sync from S3: this task will download artifacts from previous pipeline to the agent. Since this pipeline has previous pipeline (TerraformCommit) as one of the materials, it has access to previous pipeline label through one of the environment variable (`GO_DEPENDENCY_LABEL_TERRAFORMMODULESYNCEDTOS3`). We can use this environment variable to figure out which folder in S3 to download artifacts. This works but quite fragile and can be broken quite easily if the structure of previous pipeline label changes or if we restructure build pipeline. In a real world usage, I would use a more robust way to find out this folder name, .e.g. approaches from this article [Pass variables to other pipelines](https://support.thoughtworks.com/hc/en-us/articles/213254026-Pass-variables-to-other-pipelines)
- Terraform Init: this step configures the backend file to be used for Staging environment using `backend.tfvars`
- Terraform Apply: this is the actual step that makes changes to Staging EC2 server. Below is the script that is called by this task:

```
PIPELINE_LABEL=$1
CONFIG_DIR=$2

cd ${CONFIG_DIR}
PACKER_BUILD_NO=$(echo ${PIPELINE_LABEL} | cut -d '.' -f1)
echo yes | terraform apply -var "packer_build_number=${PACKER_BUILD_NO}"
```

This script simply extracts build number from first stage (PackerCommit) and passes it to `terraform apply` as input variable. This is so that Terraform data source can look up correct AMI created by Packer

- Smoke Test: this is a simple post-deployment test to make sure that the EC2 server is up and Nginx is working correctly. It extracts public ip of the created EC2 server by calling `terraform output`:

```
PUBLIC_IP=$(terraform output -json | jq -r '.server_public_ip.value')
```

From this, it keeps calling `curl` to the server every 2 seconds for 60 seconds. If server is not up after 60 seconds, it will fail the build

If everything goes smoothly, you will see something like this in the build log for the first time build. It correctly identifies that a new EC2 server to be created.

![]({% asset_path 2018-06-13-terraform-staging-log %} "TerraformStaging first build log")

And when I copy the public IP in the previous screenshot and paste it to browser:

![]({% asset_path 2018-06-13-terraform-staging-nginx %} "TerraformStaging Nginx output")

As we can see, all the tasks in this step is specific to Staging and use only files in `staging` folder.

#### TerraformProduction stage

This is almost exactly the same with TerraformStaging stage. The only difference is instead of using files from `staging` folder, it uses `production` folder

That should be all. Now we have a complete pipeline that can deploy any change in infrastructure (changes in Terraform files) or change in code (Packer files) to Staging and Production.

As the final demonstration of deploying changes in code to Staging and Production, I update the text in `index.html` to `Triggered by a Code Change` and make a commit. The whole pipeline is triggered again and Terraform correctly identifies that previous server needs to be teared down and a new server needs to be spinned up for the new change:

![]({% asset_path 2018-06-13-terraform-code-change-log %} "Terraform Code Change output")

And visiting the new Public IP will give us this page:

![]({% asset_path 2018-06-13-terraform-updated-staging-nginx %} "Updated Staging")

## Summary

My takeaway after implementing this pipeline is that: we should have a clear seperation between Terraform infrastructure definition (which is equivalent to normal code) and Terraform environment specific configuration (containing Terraform state, environment specific `tfvars`). With this separation, we can apply the same build pipeline technique used in normal build delivery pipeline
