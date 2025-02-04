param name string
param location string
param enabledForTemplateDeployment bool = false
param enabledForDeployment bool = false
param enabledForDiskEncryption bool = false
param enablePurgeProtection bool = true
param enableRbacAuthorization bool = true
param enableSoftDelete bool = false
@allowed([
  'standard'
  'premium'
])
param sku string = 'standard' 
param enableDiagnostics bool = false
param logs array = []
param eventHubAuthorizationRuleId string = ''
param eventHubName string = ''
param serviceBusRuleId string = ''
param storageAccountId string = ''
param workspaceId string = ''
param tags object = {} 


resource keyvault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: sku     
    }
    tenantId: tenant().tenantId
    enabledForTemplateDeployment: enabledForTemplateDeployment 
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enablePurgeProtection: enablePurgeProtection
    enableRbacAuthorization: enableRbacAuthorization
    enableSoftDelete: enableSoftDelete  
  }  
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(enableDiagnostics == true){
  name: name
  scope: keyvault
  properties: {
    logs: logs
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    eventHubName: eventHubName
    serviceBusRuleId: serviceBusRuleId
    storageAccountId: storageAccountId
    workspaceId: workspaceId     
  }    
}

output keyVaultId string = keyvault.id
