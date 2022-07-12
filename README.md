# MAP AZURE DEVOPS RUNTIME VARIABLES TO TERRAFORM INPUT VARIABLES

Greetings my fellow Technology Advocates and Specialists.

In this Session, I will demonstrate - 
1. How to __Map Azure DevOps Runtime Variables to Terraform Input Variables.__ 
2. If at all we need to put the values in __variables.tf__ or in __tfvars__.  

| __REQUIREMENTS:-__ |
| --------- |

1. Azure Subscription.
2. Azure DevOps Organisation and Project.
3. Service Principal with Delegated Graph API Rights and Required RBAC (Typically __Contributor__ on Subscription or Resource Group)
3. Azure Resource Manager Service Connection in Azure DevOps.
4. Microsoft DevLabs Terraform Extension Installed in Azure DevOps.


| __HOW DOES MY CODE PLACEHOLDER LOOKS LIKE:-__ |
| --------- |
| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/9nal9a3obxklenm70nyk.png) |

| __OBJECTIVE:-__ |
| --------- |
| Deploy a __Resource Group__ and __User Assigned Managed Identity__ from the values provided by user in the __DevOps Runtime Variables Parameters__ and __not__ providing it again in Terraform __variables.tf or tfvars__ |


| PIPELINE CODE SNIPPET:- | 
| --------- |

| AZURE DEVOPS YAML PIPELINE (azure-pipelines-usr-mid-v1.0.yml):- | 
| --------- |

```
trigger:
  none

######################
#DECLARE PARAMETERS:-
######################
parameters:
- name: SubscriptionID
  displayName: Subscription ID Details Follow Below:-
  default: 210e66cb-55cf-424e-8daa-6cad804ab604
  values:
  -  210e66cb-55cf-424e-8daa-6cad804ab604

- name: ServiceConnection
  displayName: Service Connection Name Follows Below:-
  default: amcloud-cicd-service-connection
  values:
  -  amcloud-cicd-service-connection

- name: RGNAME
  displayName: Please Provide the Resource Group Name:-
  type: object
  default: <Please provide the required Name>

- name: USRMIDNAME
  displayName: Please Provide the User Assigned Managed Identity Name:-
  type: object
  default: <Please provide the required Name>

######################
#DECLARE VARIABLES:-
######################
variables:
  TF_VAR_RG_NAME: ${{ parameters.RGNAME }}
  TF_VAR_USR_MID_NAME: ${{ parameters.USRMIDNAME }}
  ResourceGroup: tfpipeline-rg
  StorageAccount: tfpipelinesa
  Container: terraform
  TfstateFile: UMID/usrmid.tfstate
  BuildAgent: windows-latest
  WorkingDir: $(System.DefaultWorkingDirectory)/Usr-MID
  Target: $(build.artifactstagingdirectory)/AMTF
  Environment: NonProd
  Artifact: AM

#########################
# Declare Build Agents:-
#########################
pool:
  vmImage: $(BuildAgent)

###################
# Declare Stages:-
###################
stages:

- stage: PLAN
  jobs:
  - job: PLAN
    displayName: PLAN
    steps:
# Install Terraform Installer in the Build Agent:-
    - task: ms-devlabs.custom-terraform-tasks.custom-terraform-installer-task.TerraformInstaller@0
      displayName: INSTALL TERRAFORM VERSION - LATEST
      inputs:
        terraformVersion: 'latest'
# Terraform Init:-
    - task: TerraformTaskV2@2
      displayName: TERRAFORM INIT
      inputs:
        provider: 'azurerm'
        command: 'init'
        workingDirectory: '$(workingDir)' # Az DevOps can find the required Terraform code
        backendServiceArm: '${{ parameters.ServiceConnection }}' 
        backendAzureRmResourceGroupName: '$(ResourceGroup)' 
        backendAzureRmStorageAccountName: '$(StorageAccount)'
        backendAzureRmContainerName: '$(Container)'
        backendAzureRmKey: '$(TfstateFile)'
# Terraform Validate:-
    - task: TerraformTaskV2@2
      displayName: TERRAFORM VALIDATE
      inputs:
        provider: 'azurerm'
        command: 'validate'
        workingDirectory: '$(workingDir)'
        environmentServiceNameAzureRM: '${{ parameters.ServiceConnection }}'
# Terraform Plan:-
    - task: TerraformTaskV2@2
      displayName: TERRAFORM PLAN
      inputs:
        provider: 'azurerm'
        command: 'plan'
        workingDirectory: '$(workingDir)'
        commandOptions: "--var-file=usrmid.tfvars --out=tfplan"
        environmentServiceNameAzureRM: '${{ parameters.ServiceConnection }}'
    
# Copy Files to Artifacts Staging Directory:-
    - task: CopyFiles@2
      displayName: COPY FILES ARTIFACTS STAGING DIRECTORY
      inputs:
        SourceFolder: '$(workingDir)'
        Contents: |
          **/*.tf
          **/*.tfvars
          **/*tfplan*
        TargetFolder: '$(Target)'
# Publish Artifacts:-
    - task: PublishBuildArtifacts@1
      displayName: PUBLISH ARTIFACTS
      inputs:
        targetPath: '$(Target)'
        artifactName: '$(Artifact)' 

- stage: DEPLOY
  condition: succeeded()
  dependsOn: PLAN
  jobs:
  - deployment: 
    displayName: Deploy
    environment: $(Environment)
    pool:
      vmImage: '$(BuildAgent)'
    strategy:
      runOnce:
        deploy:
          steps:
# Download Artifacts:-
          - task: DownloadBuildArtifacts@0
            displayName: DOWNLOAD ARTIFACTS
            inputs:
              buildType: 'current'
              downloadType: 'single'
              artifactName: '$(Artifact)'
              downloadPath: '$(System.ArtifactsDirectory)' 
# Install Terraform Installer in the Build Agent:-
          - task: ms-devlabs.custom-terraform-tasks.custom-terraform-installer-task.TerraformInstaller@0
            displayName: INSTALL TERRAFORM VERSION - LATEST
            inputs:
              terraformVersion: 'latest'
# Terraform Init:-
          - task: TerraformTaskV2@2 
            displayName: TERRAFORM INIT
            inputs:
              provider: 'azurerm'
              command: 'init'
              workingDirectory: '$(System.ArtifactsDirectory)/$(Artifact)/AMTF/' # Az DevOps can find the required Terraform code
              backendServiceArm: '${{ parameters.ServiceConnection }}' 
              backendAzureRmResourceGroupName: '$(ResourceGroup)' 
              backendAzureRmStorageAccountName: '$(StorageAccount)'
              backendAzureRmContainerName: '$(Container)'
              backendAzureRmKey: '$(TfstateFile)'
# Terraform Apply:-
          - task: TerraformTaskV2@2
            displayName: TERRAFORM APPLY # The terraform Plan stored earlier is used here to apply only the changes.
            inputs:
              provider: 'azurerm'
              command: 'apply'
              workingDirectory: '$(System.ArtifactsDirectory)/$(Artifact)/AMTF'
              commandOptions: '--var-file=usrmid.tfvars'
              environmentServiceNameAzureRM: '${{ parameters.ServiceConnection }}'

```

Now, let me explain each part of YAML Pipeline for better understanding.

| PART #1:- | 
| --------- |

| BELOW FOLLOWS PIPELINE RUNTIME VARIABLES CODE SNIPPET:- | 
| --------- |

```
######################
#DECLARE PARAMETERS:-
######################
parameters:
- name: SubscriptionID
  displayName: Subscription ID Details Follow Below:-
  default: 210e66cb-55cf-424e-8daa-6cad804ab604
  values:
  -  210e66cb-55cf-424e-8daa-6cad804ab604

- name: ServiceConnection
  displayName: Service Connection Name Follows Below:-
  default: amcloud-cicd-service-connection
  values:
  -  amcloud-cicd-service-connection

- name: RGNAME
  displayName: Please Provide the Resource Group Name:-
  type: object
  default: <Please provide the required Name>

- name: USRMIDNAME
  displayName: Please Provide the User Assigned Managed Identity Name:-
  type: object
  default: <Please provide the required Name>

```

| THIS IS HOW IT LOOKS WHEN YOU EXECUTE THE PIPELINE FROM AZURE DEVOPS:- | 
| --------- |

| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/fvemxx41suzx21j728fo.png) | 
| --------- |

| NOTE:- | 
| --------- |
| Please Provide the Name of the Resource Group | 
| For Example: __AMTESTMIDRG__ |
| Please Provide the Name of the User Assigned Managed Identity | 
| For Example: __AMMID100__ |


| PART #2:- | 
| --------- |

| BELOW FOLLOWS PIPELINE VARIABLES CODE SNIPPET:- | 
| --------- |

```
######################
#DECLARE VARIABLES:-
######################
variables:
  TF_VAR_RG_NAME: ${{ parameters.RGNAME }}
  TF_VAR_USR_MID_NAME: ${{ parameters.USRMIDNAME }}
  ResourceGroup: tfpipeline-rg
  StorageAccount: tfpipelinesa
  Container: terraform
  TfstateFile: UMID/usrmid.tfstate
  BuildAgent: windows-latest
  WorkingDir: $(System.DefaultWorkingDirectory)/Usr-MID
  Target: $(build.artifactstagingdirectory)/AMTF
  Environment: NonProd
  Artifact: AM

```

| __IMPORTANT TO NOTE:-__ | 
| --------- |
| User Input Values from DevOps Runtime Parameters are referenced to DevOps Variables. |
| Notice the the variables __TF_VAR_RG_NAME__ and __TF_VAR_USR_MID_NAME__.   |
| __Azure DevOps Variables__ gets automatically __mapped__ to Environment Variables in __Azure DevOps Build Agent__. |
| Environment Variables which Starts with __TF_VAR___ gets automatically mapped to __Terraform Input Variables__ |
| Refer the link to find more: https://www.terraform.io/cli/config/environment-variables |


| __GENERAL INFORMATION:-__ |
| --------- |
| Please feel free to change the values of the variables. | 
| The entire YAML pipeline is build using Parameters and variables. No Values are Hardcoded. |


| PART #3:- | 
| --------- |

| __PIPELINE STAGE DETAILS FOLLOW BELOW:-__ |
| --------- |

1. This is a __Two Stage__ Pipeline with 4 Runtime Variables - 1) Subscription ID 2) Service Connection Name 3) Resource Group Name and 4) User Assigned Managed Identity Name 
2. The Names of the Stages are - 1) PLAN and 2) DEPLOY  

| __PIPELINE STAGE - PLAN:-__ |
| --------- |

```
- stage: PLAN
  jobs:
  - job: PLAN
    displayName: PLAN
    steps:
# Install Terraform Installer in the Build Agent:-
    - task: ms-devlabs.custom-terraform-tasks.custom-terraform-installer-task.TerraformInstaller@0
      displayName: INSTALL TERRAFORM VERSION - LATEST
      inputs:
        terraformVersion: 'latest'
# Terraform Init:-
    - task: TerraformTaskV2@2
      displayName: TERRAFORM INIT
      inputs:
        provider: 'azurerm'
        command: 'init'
        workingDirectory: '$(workingDir)' # Az DevOps can find the required Terraform code
        backendServiceArm: '${{ parameters.ServiceConnection }}' 
        backendAzureRmResourceGroupName: '$(ResourceGroup)' 
        backendAzureRmStorageAccountName: '$(StorageAccount)'
        backendAzureRmContainerName: '$(Container)'
        backendAzureRmKey: '$(TfstateFile)'
# Terraform Validate:-
    - task: TerraformTaskV2@2
      displayName: TERRAFORM VALIDATE
      inputs:
        provider: 'azurerm'
        command: 'validate'
        workingDirectory: '$(workingDir)'
        environmentServiceNameAzureRM: '${{ parameters.ServiceConnection }}'
# Terraform Plan:-
    - task: TerraformTaskV2@2
      displayName: TERRAFORM PLAN
      inputs:
        provider: 'azurerm'
        command: 'plan'
        workingDirectory: '$(workingDir)'
        commandOptions: "--var-file=usrmid.tfvars --out=tfplan"
        environmentServiceNameAzureRM: '${{ parameters.ServiceConnection }}'
    
# Copy Files to Artifacts Staging Directory:-
    - task: CopyFiles@2
      displayName: COPY FILES ARTIFACTS STAGING DIRECTORY
      inputs:
        SourceFolder: '$(workingDir)'
        Contents: |
          **/*.tf
          **/*.tfvars
          **/*tfplan*
        TargetFolder: '$(Target)'
# Publish Artifacts:-
    - task: PublishBuildArtifacts@1
      displayName: PUBLISH ARTIFACTS
      inputs:
        targetPath: '$(Target)'
        artifactName: '$(Artifact)'

```

| __PLAN STAGE PERFORMS BELOW:-__ |
| --------- |

| __##__ | __TASKS__ |
| --------- | --------- |
| 1. | Terraform Installer installed in Azure DevOps Build Agent.|
| 2. | Terraform Init |
| 3. | Terraform Validate |
| 4. | Terraform Plan |
| 5. | Copy the Terraform files (Most Importantly __Terraform Plan Output__) to Artifacts Staging Directory. |
| 6. | Publish Artifacts |


| __PIPELINE STAGE - DEPLOY:-__ |
| --------- |

```
- stage: DEPLOY
  condition: succeeded()
  dependsOn: PLAN
  jobs:
  - deployment: 
    displayName: Deploy
    environment: $(Environment)
    pool:
      vmImage: '$(BuildAgent)'
    strategy:
      runOnce:
        deploy:
          steps:
# Download Artifacts:-
          - task: DownloadBuildArtifacts@0
            displayName: DOWNLOAD ARTIFACTS
            inputs:
              buildType: 'current'
              downloadType: 'single'
              artifactName: '$(Artifact)'
              downloadPath: '$(System.ArtifactsDirectory)' 
# Install Terraform Installer in the Build Agent:-
          - task: ms-devlabs.custom-terraform-tasks.custom-terraform-installer-task.TerraformInstaller@0
            displayName: INSTALL TERRAFORM VERSION - LATEST
            inputs:
              terraformVersion: 'latest'
# Terraform Init:-
          - task: TerraformTaskV2@2 
            displayName: TERRAFORM INIT
            inputs:
              provider: 'azurerm'
              command: 'init'
              workingDirectory: '$(System.ArtifactsDirectory)/$(Artifact)/AMTF/' # Az DevOps can find the required Terraform code
              backendServiceArm: '${{ parameters.ServiceConnection }}' 
              backendAzureRmResourceGroupName: '$(ResourceGroup)' 
              backendAzureRmStorageAccountName: '$(StorageAccount)'
              backendAzureRmContainerName: '$(Container)'
              backendAzureRmKey: '$(TfstateFile)'
# Terraform Apply:-
          - task: TerraformTaskV2@2
            displayName: TERRAFORM APPLY # The terraform Plan stored earlier is used here to apply only the changes.
            inputs:
              provider: 'azurerm'
              command: 'apply'
              workingDirectory: '$(System.ArtifactsDirectory)/$(Artifact)/AMTF'
              commandOptions: '--var-file=usrmid.tfvars'
              environmentServiceNameAzureRM: '${{ parameters.ServiceConnection }}'

```

| __DEPLOY STAGE PERFORMS BELOW:-__ |
| --------- |

| __##__ | __TASKS__ |
| --------- | --------- |
| 1. | __DEPLOY__ Stage will Execute only if __PLAN__ Stage completed successfully. If not, __DEPLOY__ Stage will get Skipped Automatically. |
| 2. | __DEPLOY__ Stage will Execute only after Approval. The Approval is integrated with Environment defined in the Pipeline Variable Section (__Environment: NonProd__) and applied in __DEPLOY__ Stage __Jobs__ (__environment: $(Environment)__). |
| 3. | Download the Published Artifacts. |
| 4. | Terraform Installer installed in Azure DevOps Build Agent.|
| 5. | Terraform Init |
| 6. | Terraform Apply |


| __DETAILS AND ALL TERRAFORM CODE SNIPPETS FOLLOWS BELOW:-__ |
| --------- |


| TERRAFORM (main.tf):- | 
| --------- |

```
terraform {
  required_version = ">= 1.2.0"

   backend "azurerm" {
    resource_group_name  = "tfpipeline-rg"
    storage_account_name = "tfpipelinesa"
    container_name       = "terraform"
    key                  = "UMID/usrmid.tfstate"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.2"
    }   
  }
}
provider "azurerm" {
  features {}
  skip_provider_registration = true
}

```


| TERRAFORM (usrmid.tf):- | 
| --------- |

```
## Azure Resource Group:-
resource "azurerm_resource_group" "rg" {
  name     = var.RG_NAME
  location = var.rg-location
}

## Azure User Assigned Managed Identities:-
resource "azurerm_user_assigned_identity" "az-usr-mid" {
  
  name                = var.USR_MID_NAME
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  
  depends_on          = [azurerm_resource_group.rg]
  }

```

| TERRAFORM (variables.tf):- | 
| --------- |

```
variable "RG_NAME" {
  type        = string
  description = "Name of the Resource Group"
}

variable "rg-location" {
  type        = string
  description = "Resource Group Location"
}

variable "USR_MID_NAME" {
  type        = string
  description = "Name of the User Assigned Managed Identity"
}

```

| __IMPORTANT TO NOTE:-__ |
| --------- |
| The Variable name of the __Resource Group__ and __User Assigned Managed Identities__ in __usrmid.tf__ and __variables.tf__ are in upper case. | 
| This is because Azure DevOps Pipeline variables which automatically references to Build Agent Environment Variables gets __converted to uppercase__   |
| If the variables are not defined as above, the __Pipeline waits__ for Resource Group and User Assigned Managed Identity Name as Input. |
| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/khkfw77azn2lfj8jcpn3.png) |
| The Pipeline is then cancelled manually |
| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/s41sx8o8bhypgsxwhrq0.png) |


| TERRAFORM (usrmid.tfvars):- | 
| --------- |

```
rg-location     = "West Europe"
```

| __IMPORTANT TO NOTE:-__ |
| --------- |
|  There is No __Resource Group__ and User Assigned Managed Identity Name Value provided in __tfvars__ or in __variables.tf__ |

| __ITS TIME TO TEST:-__ |
| --------- |
| __DESIRED RESULT__: Stages - __PLAN__ and __DEPLOY__ should Complete Successfully. Resource Group and User Assigned Managed Identity Resources should get deployed. Remote State file gets created. |
| __PIPELINE RUNTIME PARAMETERS WITH POPULATED VALUES:-__ |
| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/vos5b07e2vuzl2k3f98r.png) |
| __PIPELINE STAGE PLAN EXECUTED SUCCESSFULLY:-__ |
| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/0ptnup179cntsk93z6a7.JPG) |
| __PIPELINE STAGE DEPLOY WAITING APPROVAL:-__ |
| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/1jhq753ibzjwnmf9b7af.JPG) |
| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/xipdicz92omu1en90ny6.JPG) |
| __PIPELINE STAGE DEPLOY EXECUTED SUCCESSFULLY:-__ |
| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/dx4grlmj8tiob7xhsgyu.JPG) |
| __PIPELINE OVERALL EXECUTION STATUS:-__ |
| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/bh9z1s868zss62ll8thh.JPG) |
| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/npakpqxkzyps5m6m1zyt.JPG) |
| __VALIDATE RESOURCES DEPLOYED IN PORTAL:-__ |
| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/9zxipsiowjk2vfjwtdk0.jpg) |
| __VALIDATE REMOTE TERRAFORM STATE FILE:-__ |
| ![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/kbwlbbtaimfgpzvuk716.png) |
