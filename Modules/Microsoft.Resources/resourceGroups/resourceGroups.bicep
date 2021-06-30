targetScope = 'subscription'
param location string
param name string 

resource resourceGroupDef 'Microsoft.Resources/resourceGroups@2021-04-01' = {
   location: location
   name: name  
}