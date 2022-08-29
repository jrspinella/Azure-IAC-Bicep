targetScope = 'subscription'

param resourceGroupName string
param mlWorkspaceName string
param location string
param enableDiagnostics bool = false
param logAnalyticsResourceId string = ''
param azureGovernment bool = false
param tags object = {}

var storageSuffix = azureGovernment == false ? 'core.windows.net' : 'core.usgovcloudapi.net'
var acrPrivateDns = azureGovernment == false ? 'privatelink.azurecr.io' : 'privatelink.azurecr.io'
var keyvaultDns = azureGovernment == false ? 'privatelink.vaultcore.azure.net' : 'privatelink.azurecr.io'
var suffix = substring(replace(subscription().subscriptionId,'-',''),0,15)

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}
module storage '../../Modules/Microsoft.Storage/storageAccounts/storageAccounts.bicep' = {
   name: '${mlWorkspaceName}-StorageDeployment'
   scope: resourceGroup(rg.name)
   params: {
    kind: 'StorageV2'
    location: location
    accessTier: 'Hot'
    sku: 'Standard_LRS'
    name: 'ml${suffix}'
    enableDiagnostics: enableDiagnostics
    workspaceId: logAnalyticsResourceId  
    enableHierarchicalNamespace: true 
    disablePubliAccess: true
    supportsHttpsTrafficOnly: true   
    tags: tags    
   } 
}

module keyvault '../../Modules/Microsoft.KeyVaults/vaults.bicep' = {
  name: '${mlWorkspaceName}-KeyVault'
  scope: resourceGroup(rg.name)
  params: {
    location: location
    name: 'kv${suffix}'
    tags: tags      
  }  
}

module acr '../../Modules/Microsoft.ContainerRegistry/registries.bicep' = {
  name: '${mlWorkspaceName}-ContainerRegistry'
  scope: resourceGroup(rg.name) 
  params: {
    name: 'acr${suffix}'
    location: location
    sku: 'Premium' 
    tags: tags    
  } 
}

module vnet '../../Modules/Microsoft.Network/virtualNetworks/virtualNetworks.bicep' = {
  name: '${mlWorkspaceName}-VirtualNetwork'
  scope: resourceGroup(rg.name) 
  params: {
    location: location 
    tags: tags 
    networkSecurityGroups: [] 
    vnetAddressSpaces: [
      '10.160.48.0/24'
    ] 
    vnetName: 'vn${suffix}' 
    vnetDnsServers: []
    vnetSubnets: [
      {
        name: 'PrivateLink'
        addressPrefix: '10.160.48.0/26'
      }
      {
        name: 'Train'
        addressPrefix: '10.160.48.64/26'
      }
      {
        name: 'Score'
        addressPrefix: '10.160.48.128/26'
      }
      {
        name: 'AVD'
        addressPrefix: '10.160.48.192/26'
      }
    ]  
  }
}

module storagePrivateLinkBlob '../../Modules/Microsoft.Network/privateEndpoints/privateEndpoints.bicep' = {
  name: '${mlWorkspaceName}-StorageBlobPL'
  scope: resourceGroup(rg.name) 
  params: {
    location: location
    name: '${mlWorkspaceName}-StorageBlobPL'
    remoteServiceResourceId: storage.outputs.storageAccountId
    subnetResourceId: '${vnet.outputs.resourceId}/subnets/PrivateLink'
    targetSubResource: [
      'blob'
    ] 
    manual: false
    requestMessage: 'AutoDeploy'      
  } 
}

module storagePrivateLinkFile '../../Modules/Microsoft.Network/privateEndpoints/privateEndpoints.bicep' = {
  name: '${mlWorkspaceName}-StorageFilePL'
  scope: resourceGroup(rg.name) 
  params: {
    location: location
    name: '${mlWorkspaceName}-StorageFilePL'
    remoteServiceResourceId: storage.outputs.storageAccountId
    subnetResourceId: '${vnet.outputs.resourceId}/subnets/PrivateLink'
    targetSubResource: [
      'file'
    ] 
    manual: false
    requestMessage: 'AutoDeploy'      
  } 
}

module storagePrivateLinkDfs '../../Modules/Microsoft.Network/privateEndpoints/privateEndpoints.bicep' = {
  name: '${mlWorkspaceName}-StorageDfsPL'
  scope: resourceGroup(rg.name) 
  params: {
    location: location
    name: '${mlWorkspaceName}-StorageDfsPL'
    remoteServiceResourceId: storage.outputs.storageAccountId
    subnetResourceId: '${vnet.outputs.resourceId}/subnets/PrivateLink'
    targetSubResource: [
      'dfs'
    ] 
    manual: false
    requestMessage: 'AutoDeploy'      
  } 
}

module keyvaultPrivateLink '../../Modules/Microsoft.Network/privateEndpoints/privateEndpoints.bicep' = {
  name: '${mlWorkspaceName}-KeyVaultPL'
  scope: resourceGroup(rg.name) 
  params: {
    location: location
    name: '${mlWorkspaceName}-KeyVaultPL'
    remoteServiceResourceId: keyvault.outputs.keyVaultId
    subnetResourceId: '${vnet.outputs.resourceId}/subnets/PrivateLink'
    targetSubResource: [
      'vault'
    ] 
    manual: false
    requestMessage: 'AutoDeploy'      
  } 
}

module acrPrivateLink '../../Modules/Microsoft.Network/privateEndpoints/privateEndpoints.bicep' = {
  name: '${mlWorkspaceName}-AcrPL'
  scope: resourceGroup(rg.name)
  params: {
    location: location
    name: '${mlWorkspaceName}-AcrPL'
    remoteServiceResourceId: acr.outputs.acrId
    subnetResourceId: '${vnet.outputs.resourceId}/subnets/PrivateLink'
    manual: false
    requestMessage: 'AutoDeploy'
    targetSubResource: [
      'registry'
    ]       
  }    
}

module blobPlNic '../../Modules/Microsoft.Network/networkInterfaces/networkInterfaces-existing.bicep'  = {
  name: '${mlWorkspaceName}-BlobPLNicIP'
  scope: resourceGroup(rg.name)
  params: {
    name: split(storagePrivateLinkBlob.outputs.networkInterfaces[0].id,'/')[8]
  }    
}

module filePlNic '../../Modules/Microsoft.Network/networkInterfaces/networkInterfaces-existing.bicep'  = {
  name: '${mlWorkspaceName}-FilePLNicIP'
  scope: resourceGroup(rg.name)
  params: {
    name: split(storagePrivateLinkFile.outputs.networkInterfaces[0].id,'/')[8]
  }    
}

module dfsPlNic '../../Modules/Microsoft.Network/networkInterfaces/networkInterfaces-existing.bicep'  = {
  name: '${mlWorkspaceName}-DfsPLNicIP'
  scope: resourceGroup(rg.name)
  params: {
    name: split(storagePrivateLinkDfs.outputs.networkInterfaces[0].id,'/')[8]
  }    
}

module keyVaultPlNic '../../Modules/Microsoft.Network/networkInterfaces/networkInterfaces-existing.bicep'  = {
  name: '${mlWorkspaceName}-KeyVaultPLNicIP'
  scope: resourceGroup(rg.name)
  params: {
    name: split(keyvaultPrivateLink.outputs.networkInterfaces[0].id,'/')[8]
  }    
}

module acrPlNic '../../Modules/Microsoft.Network/networkInterfaces/networkInterfaces-existing.bicep'  = {
  name: '${mlWorkspaceName}-AcrPLNicIP'
  scope: resourceGroup(rg.name)
  params: {
    name: split(acrPrivateLink.outputs.networkInterfaces[0].id,'/')[8]
  }    
}

module blobDNSZone '../../Modules/Microsoft.Network/privateDnsZones/privateDnsZones.bicep' = {
  name: '${mlWorkspaceName}-BlobDNSZone' 
  scope: resourceGroup(rg.name)
  params: {
    zoneName: 'privatelink.blob.${storageSuffix}' 
    createARecord: true
    aRecordName: split(storage.outputs.storageAccountId,'/')[8]  
    aRecordIp: blobPlNic.outputs.ip
    vnetAssociations: [
      {
        id: vnet.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

module fileDNSZone '../../Modules/Microsoft.Network/privateDnsZones/privateDnsZones.bicep' = {
  name: '${mlWorkspaceName}-FileDNSZone' 
  scope: resourceGroup(rg.name)
  params: {
    zoneName: 'privatelink.file.${storageSuffix}' 
    createARecord: true
    aRecordName: split(storage.outputs.storageAccountId,'/')[8]  
    aRecordIp: filePlNic.outputs.ip
    vnetAssociations: [
      {
        id: vnet.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

module dfsDNSZone '../../Modules/Microsoft.Network/privateDnsZones/privateDnsZones.bicep' = {
  name: '${mlWorkspaceName}-DfsDNSZone' 
  scope: resourceGroup(rg.name)
  params: {
    zoneName: 'privatelink.dfs.${storageSuffix}' 
    createARecord: true
    aRecordName: split(storage.outputs.storageAccountId,'/')[8]  
    aRecordIp: dfsPlNic.outputs.ip
    vnetAssociations: [
      {
        id: vnet.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

module keyvaultDNSZone '../../Modules/Microsoft.Network/privateDnsZones/privateDnsZones.bicep' = {
  name: '${mlWorkspaceName}-KeyVaultDNSZone' 
  scope: resourceGroup(rg.name)
  params: {
    zoneName: keyvaultDns 
    createARecord: true
    aRecordName: split(keyvault.outputs.keyVaultId,'/')[8]  
    aRecordIp: keyVaultPlNic.outputs.ip
    vnetAssociations: [
      {
        id: vnet.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

module acrDNSZone '../../Modules/Microsoft.Network/privateDnsZones/privateDnsZones.bicep' = {
  name: '${mlWorkspaceName}-AcrDNSZone' 
  scope: resourceGroup(rg.name)
  params: {
    zoneName: acrPrivateDns 
    createARecord: true
    aRecordName: split(acr.outputs.acrId,'/')[8]  
    aRecordIp: acrPlNic.outputs.ip
    vnetAssociations: [
      {
        id: vnet.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}
