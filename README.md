# IaC Hello Azure

Eksempelprosjekt for Infrastructure as Code (IaC) utvikling i Azure med Terraform.

Dette prosjektet demonstrerer hvordan man:
- Utvikler Terraform IaC kode for Azure
- Bruker GitHub Codespaces for utviklingsmiljø
- Deployer en containerapplikasjon til Azure Container Instances
- Automatiserer deployment med GitHub Actions

## 📋 Innhold

- [Forutsetninger](#forutsetninger)
- [Oppsett av GitHub Secrets](#oppsett-av-github-secrets)
- [Komme i gang](#komme-i-gang)
- [Prosjektstruktur](#prosjektstruktur)
- [GitHub Workflows](#github-workflows)
- [Lokal utvikling](#lokal-utvikling)

## 🔧 Forutsetninger

- Azure-abonnement
- GitHub-konto
- Azure Service Principal med nødvendige tilganger

## 🔐 Oppsett av GitHub Secrets

For å kjøre workflows og deploye til Azure, må følgende secrets konfigureres i GitHub repository:

### 1. Opprett Azure Service Principal

```bash
az login
az ad sp create-for-rbac --name "github-actions-hello-azure" \
  --role contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth
```

### 2. Konfigurer GitHub Secrets

Gå til repository → Settings → Secrets and variables → Actions, og legg til følgende secrets:

#### Azure Credentials
- **AZURE_CREDENTIALS**: JSON output fra Service Principal kommandoen ovenfor
- **ARM_CLIENT_ID**: Application (client) ID fra Service Principal
- **ARM_CLIENT_SECRET**: Client secret fra Service Principal
- **ARM_SUBSCRIPTION_ID**: Din Azure Subscription ID
- **ARM_TENANT_ID**: Din Azure Tenant ID

#### Terraform State Backend (valgfritt)
Hvis du bruker remote state backend:
- **TF_STATE_RESOURCE_GROUP**: Navn på resource group for Terraform state
- **TF_STATE_STORAGE_ACCOUNT**: Navn på storage account for Terraform state
- **TF_STATE_CONTAINER**: Navn på blob container for Terraform state

#### Container Registry
- **ACR_NAME**: Navn på Azure Container Registry (f.eks. "acrhelloazure")

### 3. Opprett Terraform State Backend (valgfritt men anbefalt)

```bash
# Variabler
RESOURCE_GROUP_NAME="rg-terraform-state"
STORAGE_ACCOUNT_NAME="sttfstate$(openssl rand -hex 4)"
CONTAINER_NAME="tfstate"
LOCATION="norwayeast"

# Opprett resource group
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

# Opprett storage account
az storage account create \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $STORAGE_ACCOUNT_NAME \
  --sku Standard_LRS \
  --encryption-services blob

# Opprett blob container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME
```

## 🚀 Komme i gang

### Alternativ 1: Bruk GitHub Codespaces (anbefalt)

1. Klikk på **Code** → **Codespaces** → **Create codespace on main**
2. Vent til containeren er bygget (inkluderer Terraform og Azure CLI)
3. Logg inn på Azure:
   ```bash
   az login
   ```
4. Naviger til terraform-mappen og kjør:
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

### Alternativ 2: Lokal utvikling

1. Installer verktøy:
   - [Terraform](https://www.terraform.io/downloads)
   - [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
   - [Docker](https://docs.docker.com/get-docker/)

2. Klon repository:
   ```bash
   git clone https://github.com/HNIKT-Tjenesteutvikling-Systemutvikling/iac-hello-azure.git
   cd iac-hello-azure
   ```

3. Logg inn på Azure:
   ```bash
   az login
   ```

4. Deploy infrastruktur:
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

### Alternativ 3: Automatisk deployment med GitHub Actions

1. Push endringer til `main` branch
2. Workflows kjører automatisk:
   - **terraform-deploy.yml**: Deployer infrastruktur
   - **docker-build.yml**: Bygger og pusher Docker image

## 📁 Prosjektstruktur

```
iac-hello-azure/
├── .devcontainer/
│   └── devcontainer.json       # GitHub Codespaces konfigurasjon
├── .github/
│   └── workflows/
│       ├── docker-build.yml    # Workflow for Docker image
│       └── terraform-deploy.yml # Workflow for Terraform deployment
├── docker/
│   ├── Dockerfile              # Dockerfile for nginx container
│   └── index.html              # Custom HTML side
├── terraform/
│   ├── main.tf                 # Terraform provider konfigurasjon
│   ├── variables.tf            # Input variabler
│   ├── resources.tf            # Azure ressurser
│   ├── outputs.tf              # Output verdier
│   └── backend.hcl.example     # Eksempel på backend konfigurasjon
└── README.md
```

## 🔄 GitHub Workflows

### Terraform Deploy Workflow

Kjører automatisk når:
- Endringer pushes til `main` branch i `terraform/` mappen
- Pull request opprettes med endringer i `terraform/` mappen
- Manuelt trigget via workflow_dispatch

Steg:
1. Terraform format check
2. Terraform init (med backend konfigurasjon)
3. Terraform validate
4. Terraform plan
5. Terraform apply (kun på push til main)

### Docker Build Workflow

Kjører automatisk når:
- Endringer pushes til `main` branch i `docker/` mappen
- Manuelt trigget via workflow_dispatch

Steg:
1. Bygger Docker image
2. Tagger med commit SHA og "latest"
3. Pusher til Azure Container Registry

## 💻 Lokal utvikling

### Teste Docker image lokalt

```bash
cd docker
docker build -t hello-azure .
docker run -p 8080:80 hello-azure
```

Åpne nettleseren på http://localhost:8080

### Terraform kommandoer

```bash
cd terraform

# Initialiser Terraform
terraform init

# Valider konfigurasjon
terraform validate

# Formatere kode
terraform fmt -recursive

# Se planlagte endringer
terraform plan

# Appliser endringer
terraform apply

# Se outputs
terraform output

# Destroy ressurser
terraform destroy
```

## 🛠️ Tilpassing

### Endre ressursnavn

Rediger `terraform/variables.tf` for å endre standardverdier:

```hcl
variable "resource_group_name" {
  default = "rg-hello-azure"  # Endre her
}

variable "acr_name" {
  # ACR-navn må være globalt unikt og kun inneholde små bokstaver og tall
  default = "acrhelloazure"   # Må være unikt globalt - legg til et suffiks!
}

variable "container_name" {
  # Brukes også som DNS-label og må være globalt unikt
  default = "aci-hello-azure"  # Må være unikt globalt - legg til et suffiks!
}
```

**Viktig:** ACR-navn og container-navn må være globalt unike. Legg til et unikt suffiks, f.eks. dine initialer eller et tilfeldig tall:
- `acrhelloazurejhn123`
- `aci-hello-azure-jhn123`

### Endre Azure region

```hcl
variable "location" {
  default = "norwayeast"  # Endre til ønsket region
}
```

## 📝 Lisens

Dette prosjektet er lisensiert under MIT-lisensen - se LICENSE filen for detaljer.

## 🤝 Bidra

Bidrag er velkomne! Åpne gjerne issues eller pull requests.
