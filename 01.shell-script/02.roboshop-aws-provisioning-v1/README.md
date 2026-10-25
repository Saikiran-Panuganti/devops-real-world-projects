# RoboShop AWS Provisioning - V1

## 1. Project introduction

RoboShop is a sample e-commerce application made up of multiple services. The
reference documentation describes its architecture, service dependencies,
software requirements, setup order, and network ports.

This V1 project follows that RoboShop reference documentation and uses shell
scripts to provision and configure the application components on AWS
instances.

Start with the [RoboShop documentation](../01.roboshop-documentation/readme.md)
for the architecture and deployment requirements. The component-specific
instructions are also available there, for example
[MongoDB setup](../01.roboshop-documentation/01-mongodb.md).

## 2. Project goal

The goal of `02.roboshop-aws-provisioning-v1/` is to automate the setup of
RoboShop services using shell scripts. Rather than manually repeating the
installation and configuration steps on each server, this project keeps those
steps in scripts that can be reviewed and run consistently.

The repository includes scripts for MongoDB, Redis, MySQL, RabbitMQ, Catalogue,
User, Cart, Shipping, Payment, and Frontend, along with service and repository
configuration files. The `roboshop-v1.sh` script is the AWS provisioning
entry point.

The reference documentation also describes Dispatch. Its automation will be
added to this V1 project when implemented.

## Current implementation

The current V1 files are being developed and may change as the implementation
is tested and improved. This README will be extended with setup instructions,
prerequisites, execution steps, and validation details as those parts are
completed.

> **Important:** These scripts can create AWS resources, install software,
> modify system configuration, and start services. Review each script before
> running it. Use an authorized AWS account and a suitable test environment.
