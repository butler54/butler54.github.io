---
title: "PGP Keys"
description: "Chris Butler's PGP public keys"
---

# PGP Keys

This page contains my PGP public keys for secure communication.

## Primary Key

**Key ID:** `4125E4A4`  
**Fingerprint:** `4C2E838780F2FA060D7783EE1893E35DB9138038`  
**Email:** chris.butler@redhat.com

### Download Public Key

You can download my public key from the link below:

[Download PGP Public Key](/static/butler-c-keys.asc)

### Verify Key

To verify the authenticity of this key, you can check the fingerprint:

```bash
gpg --fingerprint 4C2E838780F2FA060D7783EE1893E35DB9138038
```

### Import Key

To import my public key into your GPG keyring:

```bash
gpg --import butler-c-keys.asc
```

## Usage

This key is used for:
- Email encryption and signing
- Git commit signing
- Secure communication

## Key Information

- **Algorithm:** RSA 4096-bit
- **Created:** 2024
- **Expires:** Never (unless explicitly revoked)
- **Usage:** Sign, Certify, Encrypt

## Contact

If you need to verify this key or have any questions about secure communication, please contact me via [LinkedIn](https://www.linkedin.com/in/christopherjbutler/) or email.
