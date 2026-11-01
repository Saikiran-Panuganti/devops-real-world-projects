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

1. In the AWS Console, go to **IAM → Users** and create a user for this project.
2. Give it the AWS permissions needed to create EC2 instances, security groups,
   and Route 53 records.
3. Open the user's **Security credentials** tab, choose **Create access key**,
   and select **Command Line Interface (CLI)**.
4. Save the access key ID and secret access key for the next step. AWS shows
   the secret only once.

Do not use root-account keys or share your access keys. `AdministratorAccess`
grants broad access; use it only in a disposable learning account.

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

![Example Hostinger domain registration page](https://github.com/Saikiran-Panuganti/Images/blob/main/Roboshop/hostinger-domain_name.png)

In the AWS Console, open **Route 53 → Hosted zones → Create hosted zone**.
Enter your domain name (for example, `example.com`) and create a **Public hosted
zone**. Copy the hosted zone ID; you will use it in the script. The following
image shows an example hosted-zone listing:

![Example Route 53 hosted zone](https://github.com/Saikiran-Panuganti/Images/blob/main/Roboshop/Route%2053-%20Hosted%20Zone.png)

To make the hosted zone authoritative for your domain, update the domain's
nameservers at your registrar to the four NS values Route 53 assigned to the
hosted zone. Creating a hosted zone alone does not change the registrar's
nameserver delegation. DNS delegation can take time to propagate.

### 6. Set the domain in the project scripts

Set your domain name in each of the following scripts before using them:

- In `roboshop-v1.sh`, set the AMI, instance type, domain, and hosted-zone ID:

```bash
ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="example.com"
hosted_zone_id="<ROUTE-53-HOSTED-ZONE-ID>"
```

This practice AMI is available in `us-east-1`. If you choose a different AMI,
its login method and credentials may be different.

- In `08-shipping.sh` and `10-frontend.sh`, replace the placeholder
  `domain_name` value with the same domain:

  ```bash
  domain_name="example.com"
  ```

### 7. Create service security groups and deploy the instances

For each service:

1. Create its security group in the EC2 console, using the inbound rules below.
   Create it in the same region and VPC as the instance.
2. From Windows Git Bash, run `sh roboshop-v1.sh <service-id>`.
3. In **EC2 → Instances**, confirm the instance appears with name
   `roboshop-<service-id>` and reaches **Running**.
4. In **Route 53 → Hosted zones → your domain → Records**, confirm the
   `<service-id>.<your-domain>` A record exists. For example, with
   `saikiranaws.store`, MongoDB should be `mongodb.saikiranaws.store`.
5. SSH as `ec2-user`, clone this repository, run the matching setup script,
   and check its log as shown in that service's section.

The practice AMI (`ami-0055977a6e828a4f4`) uses username `ec2-user` and
password `DevOps321`; no PEM file is used in these login steps. This shared
password is for a learning lab only. SSH from `0.0.0.0/0` exposes port 22 to
the internet, so restrict it to your IP when possible.

#### 1) `roboshop-mongodb`

Create `roboshop-mongodb` and add these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access (temporary lab use; see warning above) |
| 27017 | TCP | `roboshop-catalogue` | Catalogue reads products and loads master data |
| 27017 | TCP | `roboshop-user` | User reads/writes user accounts and orders |

From Windows Git Bash, create the instance:

```bash
sh roboshop-v1.sh mongodb
```

Check that EC2 shows `roboshop-mongodb` as **Running** and that Route 53 has
`mongodb.<your-domain>` (for example, `mongodb.saikiranaws.store`).

SSH to the instance:

```bash
ssh ec2-user@<instance-public-ip>
```

Login credentials: Username `ec2-user`; enter password `DevOps321` when
prompted.

On the MongoDB instance, clone the project and run its setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/02.roboshop-aws-provisioning-v1
sudo bash 01-mongodb.sh
```

Check the log to confirm the service configured successfully or to find any errors:

```bash
sudo tail -f /var/log/roboshop/01-mongodb.sh.log
```

#### 2) `roboshop-redis`

Create `roboshop-redis` and add these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access (temporary lab use; see warning above) |
| 6379 | TCP | `roboshop-user` | User guest ID counter |
| 6379 | TCP | `roboshop-cart` | Stores the carts |

From Windows Git Bash, create the instance:

```bash
sh roboshop-v1.sh redis
```

Check that EC2 shows `roboshop-redis` as **Running** and that Route 53 has
`redis.<your-domain>` (for example, `redis.saikiranaws.store`).

SSH to the instance:

```bash
ssh ec2-user@<instance-public-ip>
```

Login credentials: Username `ec2-user`; enter password `DevOps321` when
prompted.

On the Redis instance, clone the project and run its setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/02.roboshop-aws-provisioning-v1
sudo bash 02-redis.sh
```

Check the log to confirm the service configured successfully or to find any errors:

```bash
sudo tail -f /var/log/roboshop/02-redis.sh.log
```

#### 3) `roboshop-mysql`

Create `roboshop-mysql` and add these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access (temporary lab use; see warning above) |
| 3306 | TCP | `roboshop-shipping` | Shipping reads city/distance data and loads master data |

From Windows Git Bash, create the instance:

```bash
sh roboshop-v1.sh mysql
```

Check that EC2 shows `roboshop-mysql` as **Running** and that Route 53 has
`mysql.<your-domain>` (for example, `mysql.saikiranaws.store`).

SSH to the instance:

```bash
ssh ec2-user@<instance-public-ip>
```

Login credentials: Username `ec2-user`; enter password `DevOps321` when
prompted.

On the MySQL instance, clone the project and run its setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/02.roboshop-aws-provisioning-v1
sudo bash 03-mysql.sh
```

Check the log to confirm the service configured successfully or to find any errors:

```bash
sudo tail -f /var/log/roboshop/03-mysql.sh.log
```

#### 4) `roboshop-rabbitmq`

Create `roboshop-rabbitmq` and add these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access (temporary lab use; see warning above) |
| 5672 | TCP | `roboshop-payment` | Payment publishes orders |
| 5672 | TCP | `roboshop-dispatch` | Dispatch consumes orders; only needed if Dispatch is deployed |
| 15672 | TCP | `MY-IP/32` | Optional RabbitMQ management UI |

From Windows Git Bash, create the instance:

```bash
sh roboshop-v1.sh rabbitmq
```

Check that EC2 shows `roboshop-rabbitmq` as **Running** and that Route 53 has
`rabbitmq.<your-domain>` (for example, `rabbitmq.saikiranaws.store`).

SSH to the instance:

```bash
ssh ec2-user@<instance-public-ip>
```

Login credentials: Username `ec2-user`; enter password `DevOps321` when
prompted.

On the RabbitMQ instance, clone the project and run its setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/02.roboshop-aws-provisioning-v1
sudo bash 04-rabbitmq.sh
```

Check the log to confirm the service configured successfully or to find any errors:

```bash
sudo tail -f /var/log/roboshop/04-rabbitmq.sh.log
```

#### 5) `roboshop-catalogue`

Create `roboshop-catalogue` and add these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access (temporary lab use; see warning above) |
| 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| 8080 | TCP | `roboshop-cart` | Cart checks product price and stock |

From Windows Git Bash, create the instance:

```bash
sh roboshop-v1.sh catalogue
```

Check that EC2 shows `roboshop-catalogue` as **Running** and that Route 53 has
`catalogue.<your-domain>` (for example, `catalogue.saikiranaws.store`).

SSH to the instance:

```bash
ssh ec2-user@<instance-public-ip>
```

Login credentials: Username `ec2-user`; enter password `DevOps321` when
prompted.

On the Catalogue instance, clone the project and run its setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/02.roboshop-aws-provisioning-v1
sudo bash 05-catalogue.sh
```

Check the log to confirm the service configured successfully or to find any errors:

```bash
sudo tail -f /var/log/roboshop/05-catalogue.sh.log
```

#### 6) `roboshop-user`

Create `roboshop-user` and add these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access (temporary lab use; see warning above) |
| 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| 8080 | TCP | `roboshop-payment` | Payment checks users and saves orders |

From Windows Git Bash, create the instance:

```bash
sh roboshop-v1.sh user
```

Check that EC2 shows `roboshop-user` as **Running** and that Route 53 has
`user.<your-domain>` (for example, `user.saikiranaws.store`).

SSH to the instance:

```bash
ssh ec2-user@<instance-public-ip>
```

Login credentials: Username `ec2-user`; enter password `DevOps321` when
prompted.

On the User instance, clone the project and run its setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/02.roboshop-aws-provisioning-v1
sudo bash 06-user.sh
```

Check the log to confirm the service configured successfully or to find any errors:

```bash
sudo tail -f /var/log/roboshop/06-user.sh.log
```

#### 7) `roboshop-cart`

Create `roboshop-cart` and add these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access (temporary lab use; see warning above) |
| 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| 8080 | TCP | `roboshop-shipping` | Shipping adds shipping cost to the cart |
| 8080 | TCP | `roboshop-payment` | Payment empties the cart after an order |

From Windows Git Bash, create the instance:

```bash
sh roboshop-v1.sh cart
```

Check that EC2 shows `roboshop-cart` as **Running** and that Route 53 has
`cart.<your-domain>` (for example, `cart.saikiranaws.store`).

SSH to the instance:

```bash
ssh ec2-user@<instance-public-ip>
```

Login credentials: Username `ec2-user`; enter password `DevOps321` when
prompted.

On the Cart instance, clone the project and run its setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/02.roboshop-aws-provisioning-v1
sudo bash 07-cart.sh
```

Check the log to confirm the service configured successfully or to find any errors:

```bash
sudo tail -f /var/log/roboshop/07-cart.sh.log
```

#### 8) `roboshop-shipping`

Create `roboshop-shipping` and add these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access (temporary lab use; see warning above) |
| 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |

From Windows Git Bash, create the instance:

```bash
sh roboshop-v1.sh shipping
```

Check that EC2 shows `roboshop-shipping` as **Running** and that Route 53 has
`shipping.<your-domain>` (for example, `shipping.saikiranaws.store`).

SSH to the instance:

```bash
ssh ec2-user@<instance-public-ip>
```

Login credentials: Username `ec2-user`; enter password `DevOps321` when
prompted.

On the Shipping instance, clone the project and run its setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/02.roboshop-aws-provisioning-v1
sudo bash 08-shipping.sh
```

Check the log to confirm the service configured successfully or to find any errors:

```bash
sudo tail -f /var/log/roboshop/08-shipping.sh.log
```

#### 9) `roboshop-payment`

Create `roboshop-payment` and add these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access (temporary lab use; see warning above) |
| 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |

From Windows Git Bash, create the instance:

```bash
sh roboshop-v1.sh payment
```

Check that EC2 shows `roboshop-payment` as **Running** and that Route 53 has
`payment.<your-domain>` (for example, `payment.saikiranaws.store`).

SSH to the instance:

```bash
ssh ec2-user@<instance-public-ip>
```

Login credentials: Username `ec2-user`; enter password `DevOps321` when
prompted.

On the Payment instance, clone the project and run its setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/02.roboshop-aws-provisioning-v1
sudo bash 09-payment.sh
```

Check the log to confirm the service configured successfully or to find any errors:

```bash
sudo tail -f /var/log/roboshop/09-payment.sh.log
```

#### 10) `roboshop-frontend`

Create `roboshop-frontend` and add these inbound rules:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH access (temporary lab use; see warning above) |
| 80 | TCP | `0.0.0.0/0` | HTTP access to the website |

From Windows Git Bash, create the instance:

```bash
sh roboshop-v1.sh frontend
```

Check that EC2 shows `roboshop-frontend` as **Running** and that Route 53 has
`frontend.<your-domain>` (for example, `frontend.saikiranaws.store`). Frontend
uses the instance's public IP; backend records use private IPs.

SSH to the instance:

```bash
ssh ec2-user@<instance-public-ip>
```

Login credentials: Username `ec2-user`; enter password `DevOps321` when
prompted.

On the Frontend instance, clone the project and run its setup script:

```bash
cd /home/ec2-user
git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
cd /home/ec2-user/devops-real-world-projects/01.shell-script/02.roboshop-aws-provisioning-v1
sudo bash 10-frontend.sh
```

Check the log to confirm the service configured successfully or to find any errors:

```bash
sudo tail -f /var/log/roboshop/10-frontend.sh.log
```

After Frontend configuration completes, open
`http://<FRONTEND-PUBLIC-IP>` in a browser and confirm the RoboShop application
page loads.

#### 11) Point the root domain to Frontend (optional)

The script creates `frontend.<your-domain>`. To open the site using the root
domain, such as `saikiranaws.store`, create a separate Route 53 record:

1. In AWS Console, go to **Route 53 → Hosted zones** and open your domain's
   public hosted zone.
2. Choose **Create record**.
3. Leave **Record name** blank to use the root domain.
4. Set **Record type** to `A`.
5. For **Value**, enter the current public IPv4 address of the Frontend
   instance. Do not use an old example IP; the instance's public IP may change
   if it is stopped and started.
6. Set **TTL (seconds)** to `1` (or use the value required by your setup).
7. Choose **Create records**.

After DNS updates, open `http://<your-domain>` in a browser to test the root
domain. For example, visit `http://saikiranaws.store`. The RoboShop dashboard
should appear:

![RoboShop application dashboard accessed using the domain name](https://github.com/Saikiran-Panuganti/Images/blob/main/Roboshop/Access-Domain-Name.png)

See the [RoboShop application screenshots](https://github.com/Saikiran-Panuganti/Images/tree/main/Roboshop)
for examples of the other application pages and service names.




See the [RoboShop documentation](../01.roboshop-documentation/readme.md) for
the full architecture, dependencies, health checks, and security-group
guidance.

### Optional: `roboshop-dispatch` security group

If you deploy Dispatch separately, create `roboshop-dispatch` with this
inbound rule:

| Port | Protocol | Source | Description |
|---:|---|---|---|
| 22 | TCP | `MY-IP/32` | SSH access |

Dispatch consumes messages from RabbitMQ using an outbound connection, so it
does not need inbound application ports. This V1 project does not include a
Dispatch setup script.

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

## Related repositories

- [Shell scripting learning notes](https://github.com/Saikiran-Panuganti/devops-learning-notes/tree/main/01.shell-script)
- [Shell scripting hands-on labs](https://github.com/Saikiran-Panuganti/devops-hands-on-labs/tree/main/01.shell-script)
