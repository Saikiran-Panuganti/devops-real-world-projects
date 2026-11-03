# DevOps Real-World Projects

This repository contains hands-on DevOps projects. The [Shell Scripting](01.shell-script)
folder includes RoboShop documentation and two versions of AWS provisioning
scripts that demonstrate deploying a multi-service application.

## Shell Scripting: RoboShop

RoboShop is an online store built from independent frontend, backend, and
database services. The project is organized into three parts:

### 1. RoboShop documentation

[01.roboshop-documentation](01.shell-script/01.roboshop-documentation/readme.md)
describes the application architecture and its services. It provides
service-specific setup instructions, required ports and security-group rules,
and the recommended deployment order. Use it as the reference for
understanding what each component does and how the services work together.

### 2. AWS provisioning V1

[02.roboshop-aws-provisioning-v1](01.shell-script/02.roboshop-aws-provisioning-v1/README.md)
uses shell scripts to provision RoboShop on AWS. Its launcher script requests
EC2 instances and updates Route 53 records; separate scripts install and
configure the individual services. This version is partially automated:
after provisioning, you connect to each instance and run its matching service
setup script.

### 3. AWS provisioning V2

[03.roboshop-aws-provisioning-v2](01.shell-script/03.roboshop-aws-provisioning-v2/README.md)
continues the same AWS deployment approach, while moving shared service setup
functions into [`common.sh`](01.shell-script/03.roboshop-aws-provisioning-v2/common.sh).
This reduces repeated code across service scripts and makes them easier to
maintain. Like V1, V2 still requires you to run the service setup scripts on
the provisioned instances.

## Suggested order

1. Read the [RoboShop documentation](01.shell-script/01.roboshop-documentation/readme.md)
   to understand the services and their dependencies.
2. Follow either the [V1 guide](01.shell-script/02.roboshop-aws-provisioning-v1/README.md)
   or the [V2 guide](01.shell-script/03.roboshop-aws-provisioning-v2/README.md)
   to configure AWS and deploy the project.

Both provisioning versions can create AWS resources and incur charges. Review
their instructions and scripts, use an authorized AWS account, and clean up
resources when you finish the lab.