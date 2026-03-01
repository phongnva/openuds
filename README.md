OpenUDS
=======

OpenUDS (Universal Desktop Services) is a multiplatform connection broker for:
- VDI: Windows and Linux virtual desktops administration and deployment
- App virtualization
- Desktop services consolidation
- ...

This is an Open Source project, initiated by Spanish Company ​Virtual Cable and released Open Source with the help of several Spanish Universities.

Please feel free to contribute to this project.

Notes
=====
* From 4.0 onwards (current master), OpenUDS has been splitted in several repositories and contains submodules. Remember to use "git clone --resursive ..." to fetch it ;-).
* 4.0 version is tested on Python 3.11. It will probably work on 3.12 and 3.13 too (maybe 3.10, but not tested also)

Running with Docker
===================

To run OpenUDS server using Docker Compose:

1. Navigate to the Docker deployment directory:
   ```bash
   cd server/deployment/Docker
   ```

2. Build the images:
   ```bash
   docker compose build
   ```

3. Start the services:
   ```bash
   docker compose up -d
   ```

Once started, the server will be available at `https://localhost/`.

Running with Ansible (High Availability)
========================================

To deploy OpenUDS in a production High Availability environment using Ansible:

1. Navigate to the Ansible deployment directory:
   ```bash
   cd server/deployment/Ansible
   ```

2. Follow the step-by-step instructions in the [Ansible README](server/deployment/Ansible/README.md) to configure your inventory, variables, and SSL certificates.

3. Run the full deployment playbook:
   ```bash
   ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml
   ```

Deploying Client Payloads
=========================

If you need to rebuild the OS Client installation programs (Windows `.msi`, MacOS `.pkg`, and Linux `.tar.gz`) or inject new client binaries into the backend server for users to download, an automation script is provided in the root directory:

1. Execute the client synchronization script:
   ```bash
   ./update_clients.sh
   ```

2. The script will automatically compile the Linux binaries and copy all `.msi`, `.pkg`, and `.tar.gz` endpoints into the `server/src/uds/static/clients` HTTP serving directory. Once completed, your server proxy will automatically expose the new clients.
