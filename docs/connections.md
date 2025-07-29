# Connections

⚠️ Work in progress


<https://microsoft.github.io/fabric-cli/examples/connection_examples.html>

```shell
fab ls -al '.connections'
```

```text
name                                                               id                                     type                   connectivityType   gatewayName   gatewayId   privacyLevel
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Lakehouse admin.Connection                                         4c04102e-d11a-46d3-aacb-76a30849ec07   Lakehouse              ShareableCloud     Unknown       Unknown     None
https://fabricadls.dfs.core.windows.net/ admin.Connection          0a776785-b43b-437f-820d-42e57df3b9e3   AzureDataLakeStorage   ShareableCloud     Unknown       Unknown     None
richeney.Connection                                                651b1b99-b49e-49c2-800f-65309e5949c3   GitHubSourceControl    ShareableCloud     Unknown       Unknown     Private
terraform-fabric-demo.database.windows.net;demo admin.Connection   ce1b7c5b-419e-444f-899e-bc3fa38371fd   SQL                    ShareableCloud     Unknown       Unknown     None
```

```shell
fab get .connections/terraform\-fabric\-demo.database.windows.net\;demo\ admin.Connection -fq .
```

```json
{
  "allowConnectionUsageInGateway": false,
  "id": "ce1b7c5b-419e-444f-899e-bc3fa38371fd",
  "displayName": "terraform-fabric-demo.database.windows.net;demo admin",
  "connectivityType": "ShareableCloud",
  "connectionDetails": {
    "path": "terraform-fabric-demo.database.windows.net;demo",
    "type": "SQL"
  },
  "privacyLevel": "None",
  "credentialDetails": {
    "credentialType": "OAuth2",
    "singleSignOnType": "None",
    "connectionEncryption": "Encrypted",
    "skipTestConnection": false
  }
}
```

```shell
fab get '.connections/https\:\/\/fabricadls\.dfs\.core\.windows\.net\/\ admin.Connection' -fq .
```

```json
{
  "allowConnectionUsageInGateway": false,
  "id": "651b1b99-b49e-49c2-800f-65309e5949c3",
  "displayName": "richeney",
  "connectivityType": "ShareableCloud",
  "connectionDetails": {
    "path": "https://github.com",
    "type": "GitHubSourceControl"
  },
  "privacyLevel": "Private",
  "credentialDetails": {
    "credentialType": "Key",
    "singleSignOnType": "None",
    "connectionEncryption": "NotEncrypted",
    "skipTestConnection": false
  }
}
```

```shell
fab rm '.connections/https\:\/\/fabricadls\.dfs\.core\.windows\.net\/\ admin.Connection'
```

```shell
fab create .connections/online.Connection -P
```

```text
Params for '.Connection'. Use key=value separated by commas.

Required params:
  connectionDetails.parameters.*
  connectionDetails.type
  credentialDetails.*
  credentialDetails.type

Optional params:
  connectionDetails.creationMethod
  credentialDetails.connectionEncryption
  credentialDetails.singleSignOnType
  credentialDetails.skipTestConnection
  description
  gateway|gatewayId
  privacyLevel

```

```shell

```