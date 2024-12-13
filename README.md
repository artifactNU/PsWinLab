# PsWinLab

## Overview

This suite of PowerShell scripts automates the deployment and configuration of a virtualized server environment. It covers all aspects, from initial configuration to domain controller promotion, user management, and web server deployment. The scripts ensure repeatability and reliability for environments requiring structured and automated setups.

## Prerequisites
- **Hyper-V**: Ensure that Hyper-V is installed and enabled on your system. These scripts rely on Hyper-V for VM management.
- **PowerShell**: These scripts are written in PowerShell and should be run in a PowerShell environment with administrative privileges. Minimum required version is PowerShell 5.1.
- **Configuration Files**: Some scripts require configuration files (e.g., `config.json`) to define specific settings such as IP addresses and VM names.
- **VHDX Files**: Two VHDX files are required:
  - One for Windows Server.
  - One for Windows 10 client.

## Script Descriptions

### 0. `0CONFIG.ps1` (Configuration Generator)
This script collects user input to define the environment's configuration. It creates a `config.json` file with details such as:
- Domain name, administrator credentials, and subnet settings.
- Static IP addresses for all VMs.
- VM names and roles.

This script serves as the foundational script to generate inputs for other scripts.

### 1. `1MAIN.ps1` (Environment Initialization)
This script orchestrates the creation of virtual machines (VMs) based on the configurations provided in `config.json`. It deploys VMs with predefined base VHDs, memory allocations, and unique configurations. The script performs the following tasks:
- Reads the configuration from `config.json`.
- Creates VMs with the specified configurations.
- Attaches the base VHDX file to each VM.
- Configures initial settings such as memory and network adapters.

### 2. `2CLIENTDCSRV12.ps1` (VM Preparation)
This script prepares specific VMs (Client, DC, and Server) for further configurations by applying initial setup requirements. It assumes the virtual switch is named "Intel(R) Ethernet Connection (2) I219-LM - Virtual Switch". If the environment uses a different switch name, you must update the script to reflect the correct name. The script performs the following tasks:
- Configures the VMs created by `1MAIN.ps1`.
- Applies initial setup requirements such as network settings and system updates.

### 3. `3IPNAMECONF.ps1` (Static IP and Naming)
This script configures static IP addresses and renames VMs based on the configuration defined in `config.json`. It ensures consistent network setup for all nodes. The script performs the following tasks:
- Reads the configuration from `config.json`.
- Assigns static IP addresses to each VM.
- Renames each VM according to the specified names in the configuration file.

### 4. `4PROMOTEDC.ps1` (Domain Controller Setup)
This script promotes a VM to a domain controller (DC). It installs Active Directory Domain Services, sets up a new domain (e.g., acme.local), and ensures the DC is fully operational. The script performs the following tasks:
- Installs the necessary Windows features for Active Directory.
- Promotes the VM to a domain controller.
- Configures the new domain and verifies the DC's functionality.

### 5. `5JOINDOMAIN.ps1` (Domain Join)
This script joins additional VMs to the Active Directory domain controlled by the primary DC. It verifies connectivity and domain membership for all machines. The script performs the following tasks:
- Joins each VM to the domain.
- Verifies that each VM is successfully joined to the domain.

### 6. `6CREATEOUANDUSERS.ps1` (Organizational Units and Users)
This script establishes organizational units (OUs) and creates user accounts in Active Directory. It implements a predefined structure and user assignments. The script performs the following tasks:
- Creates OUs in Active Directory.
- Creates user accounts and assigns them to the appropriate OUs.

### 7. `7SERVERCONFIG.ps1` (Server Configuration)
This script configures specific roles and features on the servers:
- **server1**: Creates a shared folder accessible by other servers.
- **server2**: Installs the IIS role and hosts a test website.
- **DC**: Configures the domain controller roles and services.

## How the Scripts Work Together
1. **Configuration**: The `0CONFIG.ps1` script collects user input and generates the `config.json` file.
2. **Environment Initialization**: The `1MAIN.ps1` script creates and configures the initial VMs based on the `config.json`.
3. **VM Preparation**: The `2CLIENTDCSRV12.ps1` script applies initial setup requirements to the VMs.
4. **Network Configuration**: The `3IPNAMECONF.ps1` script assigns static IP addresses and renames the VMs.
5. **Domain Setup**: The `4PROMOTEDC.ps1` script promotes one of the VMs to a domain controller and sets up the domain.
6. **Domain Joining**: The `5JOINDOMAIN.ps1` script joins the remaining VMs to the newly created domain.
7. **AD Configuration**: The `6CREATEOUANDUSERS.ps1` script configures organizational units and user accounts in Active Directory.
8. **Server Configuration**: The `7SERVERCONFIG.ps1` script configures specific roles and features on the servers.

## Troubleshooting
- **Hyper-V Installation**: Ensure that Hyper-V is installed and enabled on your system. You can enable Hyper-V through the "Turn Windows features on or off" dialog.
- **Administrative Privileges**: Run all scripts with administrative privileges to ensure they have the necessary permissions to make system changes.
- **Configuration Files**: Verify that all required configuration files (e.g., `config.json`) are present and correctly formatted.
- **Network Configuration**: Ensure that the virtual switch name specified in the scripts matches the actual virtual switch name in your Hyper-V environment.
- **VHDX Files**: Ensure that the required VHDX files for Windows Server and Windows 10 client are available and correctly referenced in the scripts.
- **Script Errors**: If you encounter errors, check the PowerShell output for specific error messages and address them accordingly. Common issues include missing files, incorrect paths, and insufficient permissions.
- **VM Connectivity**: Ensure that all VMs can communicate with each other over the network. Verify network settings and IP configurations.
- **Autounattend.xml Configuration**: Ensure that the `autounattend.xml` file is correctly configured on the VHDX files. Follow the official Microsoft instructions for creating and applying an `autounattend.xml` file to automate Windows setup.

By following these steps and using the provided scripts, you can automate the setup and configuration of a lab environment with multiple VMs, a domain controller, and Active Directory configurations.
