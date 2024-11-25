# ssh-cloud-setup

Aim of this project is to provide a secure way of communicating in a cloud server environment where you want to connect
via ssh to your target servers, but you also want to keep your machines not accessible from the internet.

## Architecture

In order to work with this setup you need these machines (best if part of the same trusted network overlay)

- a bastion host
- an authentication host (for running authentication services)
- one or more target servers

## Specification

- ssh access to your machines is possible exclusively from the bastion host
- ssh access to the bastion is enforced with 2FA (LDAP username and password + OTP)
- the authentication machine runs an LDAP server
- users and groups (both on bastion and targets) are provisioned by the LDAP server

## Requirements

- machines runs Debian 12 (bookworm)
- close everything properly with firewalls!

## Usage

1. Copy the script/ directory to the bastion host
    ```bash
   scp -r script/ root@bastion:/root/
   ```

2. Login to the bastion host and move to the script/ directory
    ```bash
   ssh root@bastion
   cd script/
   ```

3. Copy the example.env file to .env
    ```bash
   cp example.env .env
   ```

4. Edit .env file properly

5. Run the bastion setup script and press enter to all the prompts
    ```bash
   bash setup-bastion.sh
   ```

6. Run the target configuration script for all your targets, inserting the ssh password when required and, again hitting
   enter when prompted
    ```bash
   bash config-target.sh <target-host>
    ```

7. (optional) To provide convenient password-less access from the bastion to the targets, after the users first login,
   run as root
    ```bash
   bash ssh-key-sign.sh
    ```
   this will sign all users ssh keys with a common CA

As result, when logging in for the first time, users will be prompted for their LDAP password and then they'll see a QR
code for configuring an authenticator app (and the session will be closed!).
Starting from the second login, users will be prompted for the password and the OTP.

While on the bastion, users will be able to access the targets using the same username (and password).