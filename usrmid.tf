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