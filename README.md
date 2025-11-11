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

## 🔧 Forutsetninger

- Azure-abonnement
- GitHub-konto
- Azure Managed Identity (opprettes som en del av oppsettet)

## 🔐 Oppsett av GitHub Secrets

For å kjøre workflows og deploye til Azure, må følgende konfigureres i GitHub repository:

### 1. Opprett Azure App Registration med Federated Credentials

Dette prosjektet bruker **Managed Identities** via Azure Federated Identity (OIDC) for autentisering med GitHub Actions, som er sikrere enn service principals med hemmeligheter.

```bash
# Logg inn på Azure
az login

# Sett variabler
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
APP_NAME="github-actions-hello-azure"
REPO_OWNER="HNIKT-Tjenesteutvikling-Systemutvikling"
REPO_NAME="iac-hello-azure-template"

# Opprett App Registration
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
echo "Application (client) ID: $APP_ID"

# Opprett Service Principal
SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv)
echo "Service Principal ID: $SP_ID"

# Gi Contributor-tilgang på subscription-nivå
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID

# Opprett federated identity credential for main branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$REPO_OWNER'/'$REPO_NAME':ref:refs/heads/main",
    "description": "GitHub Actions Main Branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Opprett federated identity credential for pull requests
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-pull-requests",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$REPO_OWNER'/'$REPO_NAME':pull_request",
    "description": "GitHub Actions Pull Requests",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Hent tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Tenant ID: $TENANT_ID"
echo "Subscription ID: $SUBSCRIPTION_ID"
```

**Viktig:** Noter deg følgende verdier for bruk i GitHub Secrets:
- Application (client) ID
- Tenant ID
- Subscription ID

### 2. Konfigurer GitHub Secrets

Gå til repository → Settings → Secrets and variables → Actions, og legg til følgende secrets:

#### Azure OIDC Authentication
- **AZURE_CLIENT_ID**: Application (client) ID fra App Registration
- **AZURE_TENANT_ID**: Din Azure Tenant ID
- **AZURE_SUBSCRIPTION_ID**: Din Azure Subscription ID

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

### Alternativ 2: Automatisk deployment med GitHub Actions

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

### Hvordan bidra til dette prosjektet

Merk at all kode og historikk kan bli synlig for alle, følg åpen kildekode-praksis og tenk på hva du deler.

Sjekk gjerne ut [Github sin veiledning](https://docs.github.com/en/get-started/exploring-projects-on-github/contributing-to-a-project) som en introduksjon. Stegene under passer for prosjekter der man ikke har tilgang til å gjøre egne endringer:

#### 1. Fork og klon repository
```bash
# Fork prosjektet via GitHub UI, deretter:
git clone https://github.com/<DITT-BRUKERNAVN>/<REPOSITORY-NAVN>.git
cd <REPOSITORY-NAVN>
```

#### 2. Opprett en feature branch
```bash
# Opprett en branch for dine endringer
git checkout -b feature/min-endring
```

#### 3. Gjør endringer og commit
```bash
# Gjør dine endringer, deretter:
git add .
git commit -m "Beskrivelse av endringen"
```

#### 4. Push til din fork
```bash
git push origin feature/min-endring
```

#### 5. Opprett en Pull Request
- Gå til din fork på GitHub
- Klikk på "Compare & pull request"
- Beskriv endringene dine og send inn PR-en til `main` branch i det opprinnelige repositoryet

### Retningslinjer

- Følg eksisterende kodestil og struktur
- Test endringene dine før du sender inn PR
- Skriv klare commit-meldinger
- Oppdater dokumentasjon hvis nødvendig
- Pass på å ikke dele sensitiv informasjon i kode og git historikk

### Mer informasjon

For mer detaljer om hvordan man bidrar til åpen kildekode-prosjekter på GitHub, se:
- [GitHub Docs - Contributing to projects](https://docs.github.com/en/get-started/exploring-projects-on-github/contributing-to-a-project)
- [GitHub Docs - Fork a repo](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo)
- [GitHub Docs - Creating a pull request from a fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request-from-a-fork)
