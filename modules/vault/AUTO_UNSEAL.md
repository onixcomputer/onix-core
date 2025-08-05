# Vault Auto-Unseal Options

Instead of managing Shamir unseal keys, you can use auto-unseal mechanisms:

## 1. Transit Auto-Unseal (Vault to Vault)

Use another Vault instance to unseal this one:

```nix
settings = {
  seal = {
    transit = {
      address = "https://vault-unsealer.example.com:8200";
      token = "s.xxxxxx";
      disable_renewal = false;
      key_name = "autounseal";
      mount_path = "transit/";
    };
  };
};
```

## 2. AWS KMS Auto-Unseal

```nix
settings = {
  seal = {
    awskms = {
      region = "us-east-1";
      kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012";
    };
  };
};
```

## 3. Local Dev Mode (No Unsealing Required)

For development, Vault runs unsealed:

```nix
settings = {
  devMode = true;
  devRootTokenID = "dev-root-token";
};
```

## Benefits of Auto-Unseal

1. **No manual unsealing** after restarts
2. **No key management** - the cloud provider handles it
3. **High availability** - can unseal even if operators aren't available
4. **Audit trail** - cloud providers log key usage

## Trade-offs

1. **Dependency** on external service
2. **Cost** of cloud KMS
3. **Recovery keys** still needed for some operations
4. **Can't unseal if external service is down**