data "http" "public_ip" {
  url = "https://ipinfo.io/ip"
}

data "azurerm_client_config" "current" {}

locals {
  public_ip = data.http.public_ip.response_body
}