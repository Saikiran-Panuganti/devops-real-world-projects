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
