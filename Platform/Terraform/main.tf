#Current Platform details
data "azurerm_client_config" "Current" {}

################################################################################
#Resource Groups
################################################################################
resource "azurerm_resource_group" "RG" {
  name     = var.ResourceGroup.Name
  location = var.ResourceGroup.Location
}

################################################################################
#Data Factory
################################################################################
resource "azurerm_data_factory" "DataFactory" {
  name                = var.DataFactory.Name
  location            = azurerm_resource_group.RG.Name
  resource_group_name = azurerm_resource_group.RG.Location

  identity {
    type = "SystemAssigned"
  }

  # This is hard-coded on purpose because it is only used in Dev environment
  # vsts_configuration {
  #   account_name    = "VSOSSE"
  #   branch_name     = "develop"
  #   project_name    = "Wholesale-Asset-Voyage"
  #   repository_name = "Wholesale-Asset-Voyage"
  #   root_folder     = "/SSE.AssetVoyage.Platform/DataFactory"
  #   tenant_id       = "953b0f83-1ce6-45c3-82c9-1d847e372339"
  # }
}

################################################################################
#Databricks + associated VNET and Subnets
################################################################################
resource "azurerm_databricks_workspace" "Databricks" {
  location                      = azurerm_resource_group.RG.Location
  name                          = var.Databricks.Name
  resource_group_name           = azurerm_resource_group.RG.name
  managed_resource_group_name   = var.Databricks.ManagedResourceGroup
  sku                           = var.Databricks.Sku
  public_network_access_enabled = true

  custom_parameters {
    no_public_ip        = true
    virtual_network_id  = azurerm_virtual_network.DatabricksVnet.id
    public_subnet_name  = azurerm_subnet.DatabricksSubnetPublic.name
    private_subnet_name = azurerm_subnet.DatabricksSubnetPrivate.name
    public_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.public.id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.private.id
  }
}

resource "azurerm_virtual_network" "DatabricksVnet" {
  name                     = var.VirtualNetwork.Name
  resource_group_name      = azurerm_resource_group.RG.name
  location                 = azurerm_resource_group.RG.location
  address_space            = [var.VirtualNetwork.CIDR]
}

resource "azurerm_network_security_group" "DatabricksNSG" {
  name                     = var.VirtualNetwork.NSG
  resource_group_name      = azurerm_resource_group.RG.name
  location                 = azurerm_resource_group.RG.location
}

resource "azurerm_subnet" "DatabricksSubnetPublic" {
  name                 = var.VirtualNetwork.PublicSubnet.Name
  resource_group_name  = azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.DatabricksVnet.name
  address_prefixes     = [var.VirtualNetwork.PublicSubnet.CIDR]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "Microsoft.Databricks.workspaces"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.DatabricksSubnetPublic.id
  network_security_group_id = azurerm_network_security_group.DatabricksNSG.id
}

resource "azurerm_subnet" "DatabricksSubnetPrivate" {
  name                 = var.VirtualNetwork.PrivateSubnet.Name
  resource_group_name  = azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.DatabricksVnet.name
  address_prefixes     = [var.VirtualNetwork.PrivateSubnet.CIDR]

  delegation {
    name = "Microsoft.Databricks.workspaces"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.DatabricksSubnetPrivate.id
  network_security_group_id = azurerm_network_security_group.DatabricksNSG.id
}

################################################################################
#Data Lake
################################################################################
resource "azurerm_storage_account" "DataLake" {
  name                     = lower(var.DataLake.Name)
  resource_group_name      = azurerm_resource_group.RG.name
  location                 = azurerm_resource_group.RG.location
  account_tier             = var.DataLake.Tier
  account_replication_type = var.DataLake.Replication
  is_hns_enabled           = true
  min_tls_version          = var.DataLake.TlsVersion

  network_rules {
    bypass                     = "AzureServices"
    default_action             = "Allow"    
  }
}

#Storage Account Container
resource "azurerm_storage_container" "DataLakeContainer" {  
  for_each              = var.DataLake.Container
  name                  = each.key
  storage_account_name  = azurerm_storage_account.DataLake.name
  container_access_type = "private"
}

################################################################################
#SQL Database 
################################################################################
resource "random_string" "SQLAdminPassword" {
  length      = 24
  special     = true
  min_upper   = 2
  min_numeric = 6
  min_special = 4
}

resource "azurerm_mssql_server" "SQLServer" {
  name                         = var.SQLServer.Name
  resource_group_name          = azurerm_resource_group.RG.name
  location                     = azurerm_resource_group.RG.location
  version                      = var.SQLServer.Version
  administrator_login          = var.SQLServer.AdministratorLogin
  administrator_login_password = random_string.SQLAdminPassword.result
  minimum_tls_version          = var.SQLServer.TlsVersion
}

resource "azurerm_mssql_database" "SQLDatabase" {
  name           = var.SQLDatabase.Name
  server_id      = azurerm_mssql_server.SQLServer.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb    = var.SQLDatabase.MaxSizeGB
  sku_name       = var.SQLDatabase.SKU
  zone_redundant = var.SQLDatabase.ZoneRedundant
}

################################################################################
#Key Vault
################################################################################
resource "azurerm_key_vault" "KeyVault" {
  name                        = var.KeyVault.Name
  location                    = azurerm_resource_group.RG.location
  resource_group_name         = azurerm_resource_group.RG.name
  enabled_for_disk_encryption = true
  enabled_for_deployment      = true
  enabled_for_template_deployment = true
  tenant_id                   = data.azurerm_client_config.Current.tenant_id
  soft_delete_retention_days  = var.KeyVault.SoftDeleteRetentionDays
  purge_protection_enabled    = var.KeyVault.PurgeProtection
  sku_name                    = var.KeyVault.Sku

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Allow"    
  }
}

resource "azurerm_key_vault_secret" "SQLAdminSecret" {
  name         = "sql-admin-password"
  value        = random_string.SQLAdminPassword.result
  key_vault_id = azurerm_key_vault.KeyVault.id
}