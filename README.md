# IaC Hello Azure

Eksempelprosjekt for Infrastructure as Code (IaC) utvikling i Azure med Terraform.

Dette prosjektet demonstrerer hvordan man:
- Utvikler Terraform IaC kode for Azure
- Bruker GitHub Codespaces for utviklingsmiljø
- Deployer en containerapplikasjon til Azure Container Instances
- Automatiserer deployment med GitHub Actions

## 📋 Innhold

- [Forutsetninger](#-forutsetninger)
- [Oppsett av GitHub Secrets](#-oppsett-av-github-secrets)
- [Komme i gang](#-komme-i-gang)
- [Prosjektstruktur](#-prosjektstruktur)
- [GitHub Workflows](#-github-workflows)

## 🔧 Forutsetninger

### Grunnleggende forutsetninger

- Azure-abonnement
- GitHub-konto
- Azure Managed Identity (opprettes som en del av oppsettet)

### Utviklingsmiljø

 1. Dette prosjektet er ment å kjøre i GitHub Codespaces.
 2. Normalt vil du først [opprette ditt eget GitHub repository basert på template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template).
 3. Deretter kan du [åpne et repository i GitHub Codespaces](https://docs.github.com/en/codespaces/developing-in-a-codespace/creating-a-codespace-for-a-repository).
 4. Om du allerede har åpnet prosjektet i GitHub Codespaces, gå til [github.com/codespaces](https://github.com/codespaces) for å finne igjen instansen.

## 🔐 Oppsett av GitHub Secrets

For å kjøre workflows og deploye til Azure, må følgende konfigureres fra shell i Github Codespaces.

### 1. Opprett Azure App Registration med Federated Credentials fra CLI

```bash
# Logg inn på Azure
az login

# Sett variabler
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
REPO_OWNER="$(echo $GITHUB_REPOSITORY | cut -d "/" -f 1)"
REPO_NAME="$(echo $GITHUB_REPOSITORY | cut -d "/" -f 2)"
APP_NAME="${GITHUB_USER}-${REPO_NAME}"
echo "Opprettet variabler: SUBSCRIPTION_ID=${SUBSCRIPTION_ID}, REPO_OWNER=${REPO_OWNER}, REPO_NAME=${REPO_NAME}, APP_NAME=${APP_NAME}."

# Opprett App Registration
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
echo "Application (client) ID: APP_ID=${APP_ID}."
```

Problemløsing: Hva om jeg får feil `Directory permission is needed for the current user to register the application`?

Svar: Inntil det er en løsning på dette, så kan oppsett av Github Workflow avventes, fortsett på steg 3.

```bash
# Opprett Service Principal
SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv)
echo "Service Principal ID: SP_ID=${SP_ID}."

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
RESOURCE_GROUP_NAME="${GITHUB_USER}-rg-terraform-state"
STORAGE_ACCOUNT_NAME="sttfstate$(openssl rand -hex 4)"
CONTAINER_NAME="tfstate"
LOCATION="norwayeast"
echo "Opprettet variabler: RESOURCE_GROUP_NAME=${RESOURCE_GROUP_NAME}, STORAGE_ACCOUNT_NAME=${STORAGE_ACCOUNT_NAME}, CONTAINER_NAME=${CONTAINER_NAME}, LOCATION=${LOCATION}."

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
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login
```

## 🛠️ Tilpassing

### Endre ressursnavn (anbefalt)

Vi må overstyre `terraform/variables.tf`, legg merke til standardverdiene for følgende variabler.

```hcl
variable "resource_group_name" {
  default = "rg-hello-azure"  # Denne ønsker vi å overstyre.
}

variable "acr_name" {
  # ACR-navn må være globalt unikt og kun inneholde små bokstaver og tall
  default = "acrhelloazure"   # Må være unikt globalt.
}

variable "container_name" {
  # Brukes også som DNS-label og må være globalt unikt
  default = "aci-hello-azure"  # Må være unikt globalt.
}

variable "location" {
  default = "norwayeast"  # Endre til ønsket region, dette er valgfritt.
}
```

Det er ikke nødvendig å endre `terraform/variables.tf`, istedenfor kan vi bruke en konfigurasjonsfil som leses automatisk når vi kjører `terraform init` og `terraform plan`.

Kjør følgende kode.

```bash
TF_VARIABLES_CONFIG="${CODESPACE_VSCODE_FOLDER}/terraform/${GITHUB_USER}.auto.tfvars"
cp ${CODESPACE_VSCODE_FOLDER}/terraform/hello.auto.tfvars.example $TF_VARIABLES_CONFIG
sed -i "s/rg-hello-azure/${GITHUB_USER,,}-rg-hello-azure/g" $TF_VARIABLES_CONFIG # Merk at ",," i "${GITHUB_USER,,}" gjør brukernavn til lower case i bash.
sed -i "s/acrhelloazure/${GITHUB_USER,,}acrhelloazure/g" $TF_VARIABLES_CONFIG
sed -i "s/aci-hello-azure/${GITHUB_USER,,}-aci-hello-azure/g" $TF_VARIABLES_CONFIG
# Valgfritt å endre lokasjon. Se oversikt: https://learn.microsoft.com/en-us/azure/reliability/regions-list.
# sed -i "s/norwayeast/norwaywest/g" $TF_VARIABLES_CONFIG
```

Lagre endringen i *ditt* git repository.

```bash
echo '!'"/terraform/${GITHUB_USER}.auto.tfvars" >> "${CODESPACE_VSCODE_FOLDER}/.gitignore"
git add ${CODESPACE_VSCODE_FOLDER}/terraform/${GITHUB_USER}.auto.tfvars ${CODESPACE_VSCODE_FOLDER}/.gitignore
git commit -m "Lagt til mine egne Terraform variabler."
```

## 🚀 Komme i gang

### Alternativ 1: Bruk GitHub Codespaces (anbefalt)

Om du har fulgt guiden hit så er det mulig at du kan hoppe over stegene 1, 2 og 3.

1. Se [forutsetningene](#-forutsetninger) igjen, og pass på at du har et kjørende Codespace for de neste stegene.
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
$ tree -a -I ".git|.gitignore|*.tfbackend" --noreport --dirsfirst -n
.
├── .devcontainer
│   └── devcontainer.json
├── docker
│   ├── Dockerfile
│   └── index.html
├── .github
│   ├── workflows
│   │   ├── docker-build.yml
│   │   └── terraform-deploy.yml
│   └── CODEOWNERS
├── terraform
│   ├── hello.variables.tfbackend.example
│   ├── main.tf
│   ├── outputs.tf
│   ├── resources.tf
│   └── variables.tf
├── LICENSE
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
