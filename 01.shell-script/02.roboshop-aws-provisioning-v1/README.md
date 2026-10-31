# RoboShop AWS Provisioning - V1

## Project overview

This project follows the manual deployment process in the [RoboShop
documentation](../01.roboshop-documentation/readme.md) and uses shell scripts
to automate server creation and the installation of RoboShop components.
Instead of creating every EC2 instance by hand and repeatedly entering setup
commands, V1 provides a script for provisioning an instance and component
scripts for installing and configuring the software.

V1 is a **partially automated** deployment: `roboshop-v1.sh` creates an
instance and updates its Route 53 record, but you must still connect to each
instance, obtain the scripts, and run the matching component script yourself.
After running it, verify the service's health using the checks in the RoboShop
documentation.

## Deployment flow

1. Review the architecture, dependencies, setup order, ports, and component
   requirements in the [RoboShop documentation](../01.roboshop-documentation/readme.md).
   See, for example, the [MongoDB setup guide](../01.roboshop-documentation/01-mongodb.md).
2. Configure and run `roboshop-v1.sh` with a component name, such as:

   ```bash
   sh roboshop-v1.sh mongodb
   ```

   The script uses the component name to name the instance and its DNS record.
   Run it once for each component instance you need.
3. Connect to the new instance, clone or otherwise obtain this project on that
   server, and run the corresponding component script with the required
   privileges. For example, run `01-mongodb.sh` on the MongoDB instance.
4. Follow the component documentation to verify that the service is healthy
   before continuing with dependent services.

## AWS resources and configuration

The provisioning script needs the AMI ID, instance type, security group IDs,
domain name, and Route 53 hosted-zone ID. Configure these for your AWS account,
region, VPC, and domain before running the script. An EC2 key pair is required
if you plan to connect to instances using SSH; launching without a key pair
means you cannot use SSH key-based login.

Attach both the shared `roboshop-common` security group and the
component-specific group (for example, `roboshop-mongodb`) to each instance.
The common group should allow SSH (port 22) only from your public IP. The
component-specific group should allow the application traffic required by that
service, preferably only from the appropriate sources. Ensure both groups
belong to the VPC where the instance is launched.

After an instance is created, the script uses its private IP for backend
services and its public IP for Frontend, then creates or updates the matching
Route 53 A record. Backend names should resolve to private addresses (for
example, `mongodb.saikiranaws.store`); the Frontend domain (for example,
`saikiranaws.store`) should resolve to the public address. The configured
domain and hosted zone must match the records you intend to create.

**Implementation note:** In the current `roboshop-v1.sh`, the launch command
passes only the `roboshop-common` security group ID, and a single
`domain_name` is used to form both backend and Frontend records. To match the
design above, update the launch command to pass the component-specific
security group ID as well, and configure the backend and Frontend DNS names
appropriately if they use different domains.

## What `roboshop.conf` does

`roboshop.conf` is an Nginx configuration file used by the Frontend setup
script. It routes `/api/...` requests to the appropriate backend services using
their DNS names, serves the Frontend application, and configures shared HTTP
headers, compression, caching, health status, and gateway-error responses.
The setup script replaces `DOMAIN_NAME` with the configured domain before
installing the file in Nginx. This lets Nginx find backend services through
their DNS records instead of hard-coding their IP addresses.

## Project contents

The component scripts cover MongoDB, Redis, MySQL, RabbitMQ, Catalogue, User,
Cart, Shipping, Payment, and Frontend. The repository also contains service
unit files, package repository configuration, and `roboshop.conf`. Use the
matching component script on each server and refer to the documentation for
service dependencies and health checks.

The reference documentation also describes Dispatch; its automation is not
included in this V1 project.

> **Important:** These scripts can create AWS resources, install software,
> change system configuration, and start services. Review the scripts before
> running them, use an authorized AWS account, and test in an environment
> where you are prepared for the resulting charges and changes.
