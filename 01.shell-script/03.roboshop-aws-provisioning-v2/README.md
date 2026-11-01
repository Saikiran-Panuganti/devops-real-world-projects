# RoboShop AWS Provisioning - V2

## Project overview

V2 follows the manual setup in the [RoboShop documentation](../01.roboshop-documentation/readme.md)
and uses shell scripts to provision EC2 instances and configure RoboShop
services.

In V1, service scripts repeat common tasks such as checking for root access,
creating the application directory, downloading application files, logging,
and starting systemd services. V2 moves these shared tasks into
[`common.sh`](common.sh). Each service script sources `common.sh` and calls
only the functions it needs. This reduces duplicated code and makes the
service scripts easier to read and maintain.

V2 is still **partially automated**: `roboshop-v1.sh` requests an EC2 instance
and submits a Route 53 record change. You then connect to that instance and
run its service script manually.

## What `common.sh` provides

The shared file contains functions for:

- Checking that a service script is run with root privileges.
- Writing timestamped status messages and validating command results.
- Installing common application files under `/app`.
- Setting up Node.js, Java/Maven, or Python dependencies.
- Installing and starting systemd services.
- Restarting services and reporting script completion time.

For example, `05-catalogue.sh` sets `app_name=catalogue`, sources
`common.sh`, and calls shared setup functions instead of repeating their
implementation.

## 1. Configure AWS CLI on Windows

Use Git Bash for the commands in this guide.

### Install AWS CLI

Install [AWS CLI v2 for Windows](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html),
then reopen Git Bash and verify:

```bash
aws --version
```

### Create an IAM access key

1. In the AWS Console, go to **IAM → Users** and create a user for this lab.
2. Give it permissions for EC2, security groups, and Route 53.
3. Under **Security credentials**, choose **Create access key** and select
   **Command Line Interface (CLI)**.
4. Save the access key ID and secret access key.

Do not use root-account keys or share your access keys. `AdministratorAccess`
is broad; use it only in a disposable learning account.

### Configure and verify

Run `aws configure` in Git Bash and enter your credentials, region, and output
format:

```bash
aws configure
```

Use the region where the AMI and EC2 resources are available. This practice
AMI is in `us-east-1`.

Verify the configured identity and region:

```bash
aws sts get-caller-identity
aws configure list
```

## 2. Set up your domain and hosted zone

Register a domain with a registrar such as GoDaddy or Hostinger:

![Example Hostinger domain registration page](https://github.com/Saikiran-Panuganti/Images/blob/main/Roboshop/hostinger-domain_name.png)

In the AWS Console, create a **Public hosted zone** in **Route 53 → Hosted
zones** and note its hosted-zone ID:

![Example Route 53 hosted zone](https://github.com/Saikiran-Panuganti/Images/blob/main/Roboshop/Route%2053-%20Hosted%20Zone.png)

At your domain registrar, set the domain's nameservers to the four NS records
provided by Route 53. Creating the hosted zone alone does not delegate the
domain to Route 53.

## 3. Configure project values

Before provisioning, edit the variables near the top of
[`roboshop-v1.sh`](roboshop-v1.sh):

```bash
ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="example.com"
hosted_zone_id="<YOUR-ROUTE-53-HOSTED-ZONE-ID>"
```

Replace `example.com` and the hosted-zone placeholder with your own values.
The practice AMI is available in `us-east-1`; use an AMI available in your
selected region.

Also edit [`common.sh`](common.sh) and set the domain in valid Bash assignment
syntax:

```bash
domain_name="example.com"
```

Use the same domain in `roboshop-v1.sh` and `common.sh`. The current
`common.sh` contains a placeholder on this line; replace it before running
any service setup script. The V2 `08-shipping.sh` and `10-frontend.sh` scripts
use the shared `domain_name` from `common.sh`.

## 4. Create service security groups and deploy the instances

For each service:

1. Create its security group in the EC2 console using the rules below. Use the
   same region and VPC as the instance.
2. From Windows Git Bash, run `sh roboshop-v1.sh <service-id>`.
3. In **EC2 → Instances**, confirm `roboshop-<service-id>` reaches **Running**.
4. In **Route 53 → Hosted zones → your domain → Records**, confirm the
   `<service-id>.<your-domain>` A record exists.
5. SSH as `ec2-user`, clone the repository, run the matching V2 setup script,
   and check its log.

The practice AMI (`ami-0055977a6e828a4f4`) uses username `ec2-user` and
password `DevOps321`. This shared password is for a learning lab only. SSH
from `0.0.0.0/0` exposes port 22 publicly; restrict it to your IP when possible.
Do not expose database or backend application ports to the public internet.
Select referenced service security groups as rule sources in the AWS Console.

#### 1) `roboshop-mongodb`

Create `roboshop-mongodb` with these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access |
| 27017 | TCP | `roboshop-catalogue` | Catalogue reads products and loads master data |
| 27017 | TCP | `roboshop-user` | User reads/writes user accounts and orders |

Create the instance from Windows Git Bash:

```bash
sh roboshop-v1.sh mongodb
```

Confirm EC2 shows `roboshop-mongodb` as **Running** and Route 53 has
`mongodb.<your-domain>` (for example, `mongodb.saikiranaws.store`).

Connect and log in:

```bash
ssh ec2-user@<instance-public-ip>
```

Username: `ec2-user`; password: `DevOps321`.

On the instance, clone the project and run the MongoDB setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/03.roboshop-aws-provisioning-v2
sudo bash 01-mongodb.sh
```

Check the log for successful configuration or errors:

```bash
sudo tail -f /var/log/roboshop/01-mongodb.sh.log
```

#### 2) `roboshop-redis`

Create `roboshop-redis` with these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access |
| 6379 | TCP | `roboshop-user` | User guest ID counter |
| 6379 | TCP | `roboshop-cart` | Stores the carts |

Create the instance:

```bash
sh roboshop-v1.sh redis
```

Confirm EC2 shows `roboshop-redis` as **Running** and Route 53 has
`redis.<your-domain>` (for example, `redis.saikiranaws.store`).

Connect and log in:

```bash
ssh ec2-user@<instance-public-ip>
```

Username: `ec2-user`; password: `DevOps321`.

Clone the project and run the Redis setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/03.roboshop-aws-provisioning-v2
sudo bash 02-redis.sh
```

Check the log for successful configuration or errors:

```bash
sudo tail -f /var/log/roboshop/02-redis.sh.log
```

#### 3) `roboshop-mysql`

Create `roboshop-mysql` with these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access |
| 3306 | TCP | `roboshop-shipping` | Shipping reads city/distance data |

Create the instance:

```bash
sh roboshop-v1.sh mysql
```

Confirm EC2 shows `roboshop-mysql` as **Running** and Route 53 has
`mysql.<your-domain>` (for example, `mysql.saikiranaws.store`).

Connect and log in:

```bash
ssh ec2-user@<instance-public-ip>
```

Username: `ec2-user`; password: `DevOps321`.

Clone the project and run the MySQL setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/03.roboshop-aws-provisioning-v2
sudo bash 03-mysql.sh
```

Check the log for successful configuration or errors:

```bash
sudo tail -f /var/log/roboshop/03-mysql.sh.log
```

#### 4) `roboshop-rabbitmq`

Create `roboshop-rabbitmq` with these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access |
| 5672 | TCP | `roboshop-payment` | Payment publishes orders |
| 5672 | TCP | `roboshop-dispatch` | Dispatch consumes orders, if deployed separately |
| 15672 | TCP | `MY-IP/32` | Optional management UI |

Create the instance:

```bash
sh roboshop-v1.sh rabbitmq
```

Confirm EC2 shows `roboshop-rabbitmq` as **Running** and Route 53 has
`rabbitmq.<your-domain>` (for example, `rabbitmq.saikiranaws.store`).

Connect and log in:

```bash
ssh ec2-user@<instance-public-ip>
```

Username: `ec2-user`; password: `DevOps321`.

Clone the project and run the RabbitMQ setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/03.roboshop-aws-provisioning-v2
sudo bash 04-rabbitmq.sh
```

Check the log for successful configuration or errors:

```bash
sudo tail -f /var/log/roboshop/04-rabbitmq.sh.log
```

#### 5) `roboshop-catalogue`

Create `roboshop-catalogue` with these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access |
| 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| 8080 | TCP | `roboshop-cart` | Cart checks product price and stock |

Create the instance:

```bash
sh roboshop-v1.sh catalogue
```

Confirm EC2 shows `roboshop-catalogue` as **Running** and Route 53 has
`catalogue.<your-domain>` (for example, `catalogue.saikiranaws.store`).

Connect and log in:

```bash
ssh ec2-user@<instance-public-ip>
```

Username: `ec2-user`; password: `DevOps321`.

Clone the project and run the Catalogue setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/03.roboshop-aws-provisioning-v2
sudo bash 05-catalogue.sh
```

Check the log for successful configuration or errors:

```bash
sudo tail -f /var/log/roboshop/05-catalogue.sh.log
```

#### 6) `roboshop-user`

Create `roboshop-user` with these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access |
| 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| 8080 | TCP | `roboshop-payment` | Payment checks users and saves orders |

Create the instance:

```bash
sh roboshop-v1.sh user
```

Confirm EC2 shows `roboshop-user` as **Running** and Route 53 has
`user.<your-domain>` (for example, `user.saikiranaws.store`).

Connect and log in:

```bash
ssh ec2-user@<instance-public-ip>
```

Username: `ec2-user`; password: `DevOps321`.

Clone the project and run the User setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/03.roboshop-aws-provisioning-v2
sudo bash 06-user.sh
```

Check the log for successful configuration or errors:

```bash
sudo tail -f /var/log/roboshop/06-user.sh.log
```

#### 7) `roboshop-cart`

Create `roboshop-cart` with these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access |
| 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| 8080 | TCP | `roboshop-shipping` | Shipping adds cost to the cart |
| 8080 | TCP | `roboshop-payment` | Payment empties the cart |

Create the instance:

```bash
sh roboshop-v1.sh cart
```

Confirm EC2 shows `roboshop-cart` as **Running** and Route 53 has
`cart.<your-domain>` (for example, `cart.saikiranaws.store`).

Connect and log in:

```bash
ssh ec2-user@<instance-public-ip>
```

Username: `ec2-user`; password: `DevOps321`.

Clone the project and run the Cart setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/03.roboshop-aws-provisioning-v2
sudo bash 07-cart.sh
```

Check the log for successful configuration or errors:

```bash
sudo tail -f /var/log/roboshop/07-cart.sh.log
```

#### 8) `roboshop-shipping`

Create `roboshop-shipping` with these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access |
| 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |

Create the instance:

```bash
sh roboshop-v1.sh shipping
```

Confirm EC2 shows `roboshop-shipping` as **Running** and Route 53 has
`shipping.<your-domain>` (for example, `shipping.saikiranaws.store`).

Connect and log in:

```bash
ssh ec2-user@<instance-public-ip>
```

Username: `ec2-user`; password: `DevOps321`.

Clone the project and run the Shipping setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/03.roboshop-aws-provisioning-v2
sudo bash 08-shipping.sh
```

Check the log for successful configuration or errors:

```bash
sudo tail -f /var/log/roboshop/08-shipping.sh.log
```

#### 9) `roboshop-payment`

Create `roboshop-payment` with these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access |
| 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |

Create the instance:

```bash
sh roboshop-v1.sh payment
```

Confirm EC2 shows `roboshop-payment` as **Running** and Route 53 has
`payment.<your-domain>` (for example, `payment.saikiranaws.store`).

Connect and log in:

```bash
ssh ec2-user@<instance-public-ip>
```

Username: `ec2-user`; password: `DevOps321`.

Clone the project and run the Payment setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/03.roboshop-aws-provisioning-v2
sudo bash 09-payment.sh
```

Check the log for successful configuration or errors:

```bash
sudo tail -f /var/log/roboshop/09-payment.sh.log
```

#### 10) `roboshop-frontend`

Create `roboshop-frontend` with these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access |
| 80 | TCP | `0.0.0.0/0` | Public website HTTP |

Create the instance:

```bash
sh roboshop-v1.sh frontend
```

Confirm EC2 shows `roboshop-frontend` as **Running** and Route 53 has
`frontend.<your-domain>` (for example, `frontend.saikiranaws.store`). Frontend
uses the public IP; backend records use private IPs.

Connect and log in:

```bash
ssh ec2-user@<instance-public-ip>
```

Username: `ec2-user`; password: `DevOps321`.

Clone the project and run the Frontend setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/03.roboshop-aws-provisioning-v2
sudo bash 10-frontend.sh
```

Check the log for successful configuration or errors:

```bash
sudo tail -f /var/log/roboshop/10-frontend.sh.log
```

After Frontend configuration, open `http://<FRONTEND-PUBLIC-IP>` in a browser.
To use the root domain, add a Route 53 `A` record with a blank record name and
the Frontend instance's current public IP. Use an Elastic IP if you need a
stable address.

![RoboShop application dashboard accessed using the domain name](https://github.com/Saikiran-Panuganti/Images/blob/main/Roboshop/Access-Domain-Name.png)

See the [RoboShop application screenshots](https://github.com/Saikiran-Panuganti/Images/tree/main/Roboshop)
for other application pages.

The scripts source `common.sh` using a relative path, so run each setup script
from the V2 project directory. Application scripts that call `app_setup`
remove and recreate `/app`. The V2 project does not include a Dispatch setup
script; configure the RabbitMQ Dispatch rule only if you deploy Dispatch
separately. Refer to the [RoboShop documentation](../01.roboshop-documentation/readme.md)
for service health checks and dependencies.

### Optional: `roboshop-dispatch` security group

If you deploy Dispatch separately, create `roboshop-dispatch` with this
inbound rule:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `MY-IP/32` | SSH access |

Dispatch consumes messages from RabbitMQ using an outbound connection, so it
does not need inbound application ports. This V2 project does not include a
Dispatch setup script.

## Project contents

- `common.sh` — reusable setup functions and shared configuration.
- `roboshop-v1.sh` — EC2 provisioning and Route 53 record updates.
- `01-mongodb.sh` through `10-frontend.sh` — service-specific setup scripts.
- `*.service`, `*.repo`, and `roboshop.conf` — systemd, package repository,
  and Nginx configuration files.

The reference documentation includes Dispatch, but a Dispatch setup script is
not included in this V2 project.
