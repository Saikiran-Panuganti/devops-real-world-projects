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

## Getting started: configure AWS CLI on Windows

Before provisioning RoboShop instances, configure the AWS CLI on your Windows
computer. The commands below work in Git Bash after AWS CLI v2 is installed.

### 1. Install AWS CLI

Download and install the **AWS CLI v2 for Windows (64-bit)** using the
[official AWS installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
Close and reopen Git Bash after installation, then verify it is available:

```bash
aws --version
```

### 2. Create credentials for the lab

In the AWS Management Console, create an IAM identity for CLI access and
generate an access key intended for **Command Line Interface (CLI)** use. For
a basic learning setup:

1. Open **IAM → Users → Create user** and create a dedicated user for this lab.
2. Grant the user the permissions described below. Do not use root-account
   access keys.
3. Open the user's **Security credentials** tab, choose **Create access key**,
   select the CLI use case, and follow the prompts to create the key.

For a disposable learning account, the project may require permissions for
EC2, security groups, and Route 53. Attaching the AWS managed
`AdministratorAccess` policy grants broad access to the account; use it only
if you understand and accept that risk, preferably in a separate lab account.
For ongoing or production use, create a policy limited to the specific actions
and resources the project needs. AWS recommends temporary credentials and
least-privilege permissions where possible.

Copy the access key ID and secret access key when AWS displays them. The secret
is shown only once. Never paste either key into a script, README, source
control, screenshot, or chat. If a key is exposed, deactivate and replace it
immediately.

### 3. Configure the AWS CLI

In Git Bash, run:

```bash
aws configure
```

Enter the values when prompted:

```text
AWS Access Key ID: <your access key ID>
AWS Secret Access Key: <your secret access key>
Default region name: us-east-1
Default output format: json
```

Use the AWS region where your AMI, security groups, and EC2 instances should
exist. The Route 53 hosted zone is a global service, but its ID must still be
the one for your domain. The CLI stores credentials under your Windows user
profile (typically `~/.aws/credentials` and `~/.aws/config`); do not add these
files to the repository.

### 4. Verify the configured identity

Run:

```bash
aws sts get-caller-identity
```

The command should return the AWS account and identity associated with the
configured credentials, for example:

```json
{
  "UserId": "AIDAXXXXXXXXXXXXX",
  "Account": "123456789012",
  "Arn": "arn:aws:iam::123456789012:user/devops-user"
}
```

Confirm that the account and identity are the ones you intend to use. This
check does not verify that the identity has all permissions required to
provision the project.

### 5. Register a domain and create a Route 53 hosted zone

You need a domain name that you own. Register one through a domain registrar
such as GoDaddy or Hostinger. The image below shows an example of a domain
registration page; the interface may differ over time.

![Example Hostinger domain registration page](https://github.com/Saikiran-Panuganti/Images/blob/main/hostinger-domain_name.png)

In the AWS Console, open **Route 53 → Hosted zones → Create hosted zone**.
Enter your domain name (for example, `example.com`) and create a **Public hosted
zone**. Copy the hosted zone ID; you will use it in the script. The following
image shows an example hosted-zone listing:

![Example Route 53 hosted zone](https://github.com/Saikiran-Panuganti/Images/blob/main/Route%2053-%20Hosted%20Zone.png)

To make the hosted zone authoritative for your domain, update the domain's
nameservers at your registrar to the four NS values Route 53 assigned to the
hosted zone. Creating a hosted zone alone does not change the registrar's
nameserver delegation. DNS delegation can take time to propagate.

### 6. Set the domain in the project scripts

Set your domain name in each of the following scripts before using them:

- In `roboshop-v1.sh`, set the AMI, instance type, domain, and hosted-zone ID:

```bash
ami_id="<AMI-ID>"
instance_type="t3.micro"
domain_name="example.com"
hosted_zone_id="<ROUTE-53-HOSTED-ZONE-ID>"
```

- In `08-shipping.sh` and `10-frontend.sh`, replace the placeholder
  `domain_name` value with the same domain:

  ```bash
  domain_name="example.com"
  ```

### 7. Create the security groups in AWS

Create the security groups manually in **EC2 → Security Groups → Create
security group**. Do not create them from a component install script. Create
them in the same AWS region and VPC where the instances will run. Create all
the service groups first, then add rules that use another security group as
the source; choose the source group itself, not its name as a CIDR value.

Attach the shared `roboshop-common` group to every instance. Its only inbound
rule should allow SSH (TCP 22) from your current public IP with a `/32` mask.
The component group allows only the application traffic listed below. The
reference documentation repeats the SSH rule in each service group; when using
`roboshop-common` on every instance, the SSH rule in that shared group is
sufficient, so you do not need to duplicate SSH in every component group.

| Security group | Port | Protocol | Inbound source | Purpose |
|---|---:|---|---|---|
| `roboshop-common` | 22 | TCP | `MY-IP/32` | SSH administration; attach this group to every instance |
| `roboshop-mongodb` | 27017 | TCP | `roboshop-catalogue` | Catalogue reads products and loads master data |
| `roboshop-mongodb` | 27017 | TCP | `roboshop-user` | User reads and writes user accounts and orders |
| `roboshop-redis` | 6379 | TCP | `roboshop-user` | User guest ID counter |
| `roboshop-redis` | 6379 | TCP | `roboshop-cart` | Cart storage |
| `roboshop-mysql` | 3306 | TCP | `roboshop-shipping` | Shipping reads city and distance data |
| `roboshop-rabbitmq` | 5672 | TCP | `roboshop-payment` | Payment publishes orders |
| `roboshop-rabbitmq` | 5672 | TCP | `roboshop-dispatch` | Dispatch consumes orders |
| `roboshop-rabbitmq` | 15672 | TCP | `MY-IP/32` | Optional RabbitMQ management UI |
| `roboshop-catalogue` | 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| `roboshop-catalogue` | 8080 | TCP | `roboshop-cart` | Cart checks product price and stock |
| `roboshop-user` | 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| `roboshop-user` | 8080 | TCP | `roboshop-payment` | Payment checks users and saves orders |
| `roboshop-cart` | 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| `roboshop-cart` | 8080 | TCP | `roboshop-shipping` | Shipping adds shipping cost to the cart |
| `roboshop-cart` | 8080 | TCP | `roboshop-payment` | Payment empties the cart after an order |
| `roboshop-shipping` | 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| `roboshop-payment` | 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| `roboshop-frontend` | 80 | TCP | `0.0.0.0/0` | Public HTTP access to the website |

Do not open database or backend ports to `0.0.0.0/0`. Keep the security
groups' default outbound access unless you have deliberately configured
outbound rules for all required package downloads and service connections.

### 8. Prepare `roboshop-v1.sh` for instance access

Before provisioning, verify that the launch command attaches **both**
`roboshop-common` and the component-specific group. The current script's
`run-instances` command attaches only `roboshop-$instance`; update it to pass
both group IDs with `--security-group-ids` (especially when using a non-default
VPC). Also provide an EC2 key pair with `--key-name` if you will connect using
SSH, and keep the matching private key securely on your Windows computer.
Without a key pair or another configured access method such as Systems Manager
Session Manager, SSH login will not be available.

### 9. Provision and configure each component

Run these steps from Git Bash in this project directory, in the documented
setup order. The component security group must exist before you run the
provisioning command.

For each instance:

1. Run `sh roboshop-v1.sh <service-id>` from Git Bash. For example,
   `sh roboshop-v1.sh mongodb`.
2. In the EC2 console, wait for the instance to be running and pass its status
   checks. Use its **public IPv4 address** to connect over SSH; backend DNS
   records still point to private IP addresses.
3. Connect as `ec2-user` with the private key for the launch key pair. In
   Git Bash, for example:

   ```bash
   ssh -i /c/Users/<your-windows-user>/.ssh/<key-file>.pem ec2-user@<instance-public-ip>
   ```

4. On the instance, clone the repository and enter the project directory:

   ```bash
   cd /home/ec2-user
   git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
   cd /home/ec2-user/devops-real-world-projects/01.shell-script/02.roboshop-aws-provisioning-v1
   ```

5. Run the matching configuration script with Bash and sudo. For example:

   ```bash
   sudo bash 01-mongodb.sh
   ```

   These scripts use Bash syntax; invoke them with `bash`, not `sh`.
6. Check the service log for errors and verify the service health using its
   documentation before provisioning the next dependent component:

   ```bash
   sudo tail -n 60 /var/log/roboshop/01-mongodb.sh.log
   sudo tail -f /var/log/roboshop/01-mongodb.sh.log
   ```

   The first command shows recent output. The `-f` command follows new log
   entries and can be stopped with `Ctrl+C`. Log filenames are based on the
   component script name.

Follow this sequence through Frontend:

| Order | Instance argument | Security group | Run on the instance | Log file |
|---:|---|---|---|---|
| 1 | `mongodb` | `roboshop-mongodb` | `sudo bash 01-mongodb.sh` | `/var/log/roboshop/01-mongodb.sh.log` |
| 2 | `redis` | `roboshop-redis` | `sudo bash 02-redis.sh` | `/var/log/roboshop/02-redis.sh.log` |
| 3 | `mysql` | `roboshop-mysql` | `sudo bash 03-mysql.sh` | `/var/log/roboshop/03-mysql.sh.log` |
| 4 | `rabbitmq` | `roboshop-rabbitmq` | `sudo bash 04-rabbitmq.sh` | `/var/log/roboshop/04-rabbitmq.sh.log` |
| 5 | `catalogue` | `roboshop-catalogue` | `sudo bash 05-catalogue.sh` | `/var/log/roboshop/05-catalogue.sh.log` |
| 6 | `user` | `roboshop-user` | `sudo bash 06-user.sh` | `/var/log/roboshop/06-user.sh.log` |
| 7 | `cart` | `roboshop-cart` | `sudo bash 07-cart.sh` | `/var/log/roboshop/07-cart.sh.log` |
| 8 | `shipping` | `roboshop-shipping` | `sudo bash 08-shipping.sh` | `/var/log/roboshop/08-shipping.sh.log` |
| 9 | `payment` | `roboshop-payment` | `sudo bash 09-payment.sh` | `/var/log/roboshop/09-payment.sh.log` |
| 10 | `frontend` | `roboshop-frontend` | `sudo bash 10-frontend.sh` | `/var/log/roboshop/10-frontend.sh.log` |

The reference documentation also defines `roboshop-dispatch`, but this V1
repository does not include a Dispatch setup script. Dispatch is therefore
not part of the deployment sequence above; the RabbitMQ rule for
`roboshop-dispatch` is needed only if you deploy that service separately.
Follow the [RoboShop documentation](../01.roboshop-documentation/readme.md) for
each service's dependencies, health checks, and detailed security-group
guidance.


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
