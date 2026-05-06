# CiCdTest (ASP.NET Core 9 Razor Pages) with CI/CD to Azure VM

This repository contains a production-ready ASP.NET Core 9 Razor Pages app and GitHub Actions deployment pipeline to an Azure Ubuntu VM.

## 1) Application

- Framework: ASP.NET Core 9 Razor Pages
- Home page: `Hello DevOps`
- Runtime endpoint: `http://127.0.0.1:5000`
- Reverse proxy: Nginx on port 80 -> Kestrel on port 5000

## 2) Files of interest

- `Program.cs` - app startup and middleware
- `Pages/Index.cshtml` - homepage UI
- `.github/workflows/ci-cd-vm.yml` - CI/CD pipeline
- `deploy/systemd/cicdtest.service` - app process manager
- `deploy/nginx/cicdtest.conf` - reverse proxy
- `deploy/scripts/vm-bootstrap.sh` - one-time VM bootstrap

## 3) Azure prerequisites

Create these Azure resources first:

- Resource group with Ubuntu 22.04 VM
- Storage account + blob container (for deployment package)

Example (optional):

```bash
az group create -n rg-cicdtest -l eastus
az vm create \
  -g rg-cicdtest \
  -n vm-cicdtest \
  --image Ubuntu2204 \
  --admin-username azureuser \
  --generate-ssh-keys
az vm open-port -g rg-cicdtest -n vm-cicdtest --port 80

az storage account create \
  -g rg-cicdtest \
  -n <globally-unique-storage-name> \
  -l eastus \
  --sku Standard_LRS
az storage container create \
  --account-name <globally-unique-storage-name> \
  --name deploy-packages \
  --auth-mode login
```

## 4) Create Service Principal (required)

Use Azure Service Principal authentication for GitHub Actions.

```bash
SUBSCRIPTION_ID="<your-subscription-id>"
RESOURCE_GROUP="rg-cicdtest"
VM_NAME="vm-cicdtest"
STORAGE_ACCOUNT="<globally-unique-storage-name>"

RG_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
STG_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"

az ad sp create-for-rbac \
  --name "gh-cicdtest-deployer" \
  --role Contributor \
  --scopes "$RG_SCOPE" \
  --sdk-auth
```

Copy the JSON output and save it as GitHub secret `AZURE_CREDENTIALS`.

Grant Storage Blob Data Contributor so the workflow can upload blobs using Azure AD:

```bash
APP_ID="<clientId-from-AZURE_CREDENTIALS>"
az role assignment create \
  --assignee "$APP_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "$STG_SCOPE"
```

## 5) GitHub secrets

Add the following repository secrets:

- `AZURE_CREDENTIALS` (full JSON from `az ad sp create-for-rbac --sdk-auth`)
- `AZURE_VM_RESOURCE_GROUP` (example: `rg-cicdtest`)
- `AZURE_VM_NAME` (example: `vm-cicdtest`)
- `AZURE_STORAGE_ACCOUNT` (storage account name)
- `AZURE_STORAGE_CONTAINER` (example: `deploy-packages`)

## 6) VM bootstrap (one-time)

1. Copy repository files to VM once (or manually create files from `deploy/`)
2. Run:

```bash
chmod +x deploy/scripts/vm-bootstrap.sh
./deploy/scripts/vm-bootstrap.sh
```

This installs Nginx, .NET 9 runtime, configures Nginx, and enables `cicdtest` systemd service.

## 7) Deployment flow in GitHub Actions

On each push to `main`, workflow performs:

1. Restore, build, publish .NET 9 app
2. Zip publish output
3. Login to Azure using Service Principal (`azure/login@v2`)
4. Upload package to Blob Storage
5. Generate short-lived read-only SAS URL
6. Execute Azure VM Run Command to:
  - stop `cicdtest` service
  - remove old files from `/var/www/cicdtest`
   - download and unzip new build
  - restart and enable `cicdtest`

## 8) Verify deployment

On VM:

```bash
sudo systemctl status cicdtest --no-pager
sudo nginx -t
curl -I http://localhost
curl -I http://localhost/health
```

From your browser:

- `http://<vm-public-ip>/` -> Hello DevOps

## 9) Troubleshooting

```bash
sudo journalctl -u cicdtest -n 100 --no-pager
sudo tail -n 100 /var/log/nginx/error.log
sudo systemctl restart cicdtest
sudo systemctl restart nginx
```
