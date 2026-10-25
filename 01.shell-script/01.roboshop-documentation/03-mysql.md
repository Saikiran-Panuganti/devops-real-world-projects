# MySQL

The developer has chosen MySQL for the shipping data: all countries, their cities and the location of each city. Shipping uses the location to work out the distance and the shipping cost.

> **Check with the developer for the exact version required. The developer has shared the version as MySQL 8.4.**

---

## Install

By default MySQL 8.0 is installed. Enable 8.4 and install it:

**You can list modules by using `dnf module list mysql`**

```shell
dnf module enable mysql:8.4 -y
dnf install mysql-server -y
```

Start & enable the MySQL service:

```shell
systemctl enable mysqld
systemctl start mysqld
```

---

## Root Password

Set the root password (use `RoboShop@1` or a password of your choice):

```bash
mysql_secure_installation --set-root-pass RoboShop@1
```

---

## Verification

```bash
mysql 
```
