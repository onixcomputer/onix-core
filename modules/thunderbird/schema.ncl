{
  default = {
    user = { type = "string", default = "brittonr", description = "Local user that owns the Thunderbird profile" },
    group = { type = "string", default = "users", description = "Primary group for Thunderbird profile files" },
    userHome = { type = "string", default = "/home/brittonr", description = "Home directory for the Thunderbird user" },
    profileName = { type = "string", default = "onix", description = "Managed Thunderbird profile name" },
    fullName = { type = "string", default = "Britton Richardson", description = "Display name for configured mail identities" },
    fastmailLabel = { type = "string", default = "Fastmail", description = "Account label for Fastmail" },
    gmailLabel = { type = "string", default = "Gmail", description = "Account label for Gmail" },
    gmailAuthMethod = { type = "enum", values = ["oauth2", "password"], default = "oauth2", description = "Thunderbird authentication mode for Gmail" },
  },
}
