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

## 4. Create service security groups

Create one security group per service in **EC2 → Security Groups**. Create
each group in the same region and VPC as the instances. For rules whose source
is another service group, select that security group as the source in the
AWS Console.

Allow SSH from `0.0.0.0/0` only for a temporary lab; it lets any IPv4 address
attempt to connect. Restrict SSH to your IP when possible. Do not expose
database or backend application ports to the public internet.

| Security group | Port | Protocol | Inbound source | Purpose |
|---|---:|---|---|---|
| `roboshop-mongodb` | 22 | TCP | `0.0.0.0/0` | SSH (temporary lab use) |
| `roboshop-mongodb` | 27017 | TCP | `roboshop-catalogue` | Catalogue reads products and loads data |
| `roboshop-mongodb` | 27017 | TCP | `roboshop-user` | User account and order data |
| `roboshop-redis` | 22 | TCP | `0.0.0.0/0` | SSH (temporary lab use) |
| `roboshop-redis` | 6379 | TCP | `roboshop-user` | User guest ID counter |
| `roboshop-redis` | 6379 | TCP | `roboshop-cart` | Cart storage |
| `roboshop-mysql` | 22 | TCP | `0.0.0.0/0` | SSH (temporary lab use) |
| `roboshop-mysql` | 3306 | TCP | `roboshop-shipping` | Shipping database access |
| `roboshop-rabbitmq` | 22 | TCP | `0.0.0.0/0` | SSH (temporary lab use) |
| `roboshop-rabbitmq` | 5672 | TCP | `roboshop-payment` | Payment publishes orders |
| `roboshop-rabbitmq` | 5672 | TCP | `roboshop-dispatch` | Dispatch consumes orders, if deployed separately |
| `roboshop-rabbitmq` | 15672 | TCP | `MY-IP/32` | Optional management UI |
| `roboshop-catalogue` | 22 | TCP | `0.0.0.0/0` | SSH (temporary lab use) |
| `roboshop-catalogue` | 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| `roboshop-catalogue` | 8080 | TCP | `roboshop-cart` | Cart checks product details |
| `roboshop-user` | 22 | TCP | `0.0.0.0/0` | SSH (temporary lab use) |
| `roboshop-user` | 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| `roboshop-user` | 8080 | TCP | `roboshop-payment` | Payment checks users and saves orders |
| `roboshop-cart` | 22 | TCP | `0.0.0.0/0` | SSH (temporary lab use) |
| `roboshop-cart` | 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| `roboshop-cart` | 8080 | TCP | `roboshop-shipping` | Shipping adds cost to the cart |
| `roboshop-cart` | 8080 | TCP | `roboshop-payment` | Payment empties the cart |
| `roboshop-shipping` | 22 | TCP | `0.0.0.0/0` | SSH (temporary lab use) |
| `roboshop-shipping` | 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| `roboshop-payment` | 22 | TCP | `0.0.0.0/0` | SSH (temporary lab use) |
| `roboshop-payment` | 8080 | TCP | `roboshop-frontend` | Frontend reverse proxy |
| `roboshop-frontend` | 22 | TCP | `0.0.0.0/0` | SSH (temporary lab use) |
| `roboshop-frontend` | 80 | TCP | `0.0.0.0/0` | Public website HTTP |

Create all service groups before adding rules that reference other service
groups. The V2 project does not include a Dispatch setup script.

`roboshop-v1.sh` currently passes the security-group name. If your VPC requires
security-group IDs, update the launch command to use `--security-group-ids`
with the ID of `roboshop-<service-id>`.

## 5. Provision, configure, and check each service

The instance name and DNS record use the service ID passed to
`roboshop-v1.sh`. Backend records use private IP addresses; Frontend uses its
public IP.

| Order | Security group | Git Bash command | EC2 instance name | Route 53 record | Service setup script |
|---:|---|---|---|---|---|
| 1 | `roboshop-mongodb` | `sh roboshop-v1.sh mongodb` | `roboshop-mongodb` | `mongodb.<your-domain>` | `01-mongodb.sh` |
| 2 | `roboshop-redis` | `sh roboshop-v1.sh redis` | `roboshop-redis` | `redis.<your-domain>` | `02-redis.sh` |
| 3 | `roboshop-mysql` | `sh roboshop-v1.sh mysql` | `roboshop-mysql` | `mysql.<your-domain>` | `03-mysql.sh` |
| 4 | `roboshop-rabbitmq` | `sh roboshop-v1.sh rabbitmq` | `roboshop-rabbitmq` | `rabbitmq.<your-domain>` | `04-rabbitmq.sh` |
| 5 | `roboshop-catalogue` | `sh roboshop-v1.sh catalogue` | `roboshop-catalogue` | `catalogue.<your-domain>` | `05-catalogue.sh` |
| 6 | `roboshop-user` | `sh roboshop-v1.sh user` | `roboshop-user` | `user.<your-domain>` | `06-user.sh` |
| 7 | `roboshop-cart` | `sh roboshop-v1.sh cart` | `roboshop-cart` | `cart.<your-domain>` | `07-cart.sh` |
| 8 | `roboshop-shipping` | `sh roboshop-v1.sh shipping` | `roboshop-shipping` | `shipping.<your-domain>` | `08-shipping.sh` |
| 9 | `roboshop-payment` | `sh roboshop-v1.sh payment` | `roboshop-payment` | `payment.<your-domain>` | `09-payment.sh` |
| 10 | `roboshop-frontend` | `sh roboshop-v1.sh frontend` | `roboshop-frontend` | `frontend.<your-domain>` | `10-frontend.sh` |

For each service, follow these steps:

1. Run its Git Bash command from the project directory.
2. In **EC2 → Instances**, confirm the named instance reaches **Running**.
3. In **Route 53 → Hosted zones → your domain → Records**, check that its A
   record exists. For example, with `saikiranaws.store`, MongoDB should be
   `mongodb.saikiranaws.store`.
4. SSH to the instance using its public IPv4 address:

   ```bash
   ssh ec2-user@<instance-public-ip>
   ```

   The practice AMI (`ami-0055977a6e828a4f4`) uses username `ec2-user` and
   password `DevOps321`. This shared password is for a learning lab only; do
   not use this AMI for sensitive workloads.
5. On the instance, clone the repository and enter the V2 project directory:

   ```bash
   cd /home/ec2-user
   git clone https://github.com/Saikiran-Panuganti/devops-real-world-projects.git
   cd /home/ec2-user/devops-real-world-projects/01.shell-script/03.roboshop-aws-provisioning-v2
   ```

6. Run the matching setup script with Bash and sudo. For example, on MongoDB:

   ```bash
   sudo bash 01-mongodb.sh
   ```

7. Check the log to confirm successful configuration or find errors:

   ```bash
   sudo tail -f /var/log/roboshop/01-mongodb.sh.log
   ```

   Replace the script name with the service's setup script. Press `Ctrl+C` to
   stop following the log. Run scripts in the order shown above and verify
   service health using the [RoboShop documentation](../01.roboshop-documentation/readme.md)
   before moving to dependent services.

> **Important:** `common.sh` uses shared variables and helper functions, so
> keep it in the same project directory as the service scripts. The scripts
> source it using a relative path. Run them from the project directory, on
> fresh lab instances, and review them before use; they install software and
> modify system configuration. Application scripts that call `app_setup`
> remove and recreate `/app`.

### Frontend and domain access

After running `10-frontend.sh`, open
`http://<FRONTEND-PUBLIC-IP>` in a browser and confirm the application loads.
The script creates `frontend.<your-domain>`. To use the root domain, create a
Route 53 `A` record with a blank record name and the Frontend instance's
current public IP. For a stable address, associate an Elastic IP with the
instance.

![RoboShop application dashboard accessed using the domain name](https://github.com/Saikiran-Panuganti/Images/blob/main/Roboshop/Access-Domain-Name.png)

See the [RoboShop application screenshots](https://github.com/Saikiran-Panuganti/Images/tree/main/Roboshop)
for other application pages.

## Project contents

- `common.sh` — reusable setup functions and shared configuration.
- `roboshop-v1.sh` — EC2 provisioning and Route 53 record updates.
- `01-mongodb.sh` through `10-frontend.sh` — service-specific setup scripts.
- `*.service`, `*.repo`, and `roboshop.conf` — systemd, package repository,
  and Nginx configuration files.

The reference documentation includes Dispatch, but a Dispatch setup script is
not included in this V2 project.
