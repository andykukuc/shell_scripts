# Certificate Generation & Renewal Script

This Bash script helps you generate, renew, and manage SSL/TLS certificates and keys for your applications or servers, using your own internal Certificate Authority (CA).

## Features

- **Interactive prompts** for application/server name, SANs, and CA management.
- **Renewal logic**: Scan any directory for existing certs/keys/CSRs, check expiration, and prompt for renewal or replacement.
- **CA management**: Use, copy, or create a new CA as needed.
- **SAN support**: Easily add DNS and IP SANs to your certificates.
- **Safe cleanup**: Prompts you to transfer files before deleting temporary output directories.

## Usage

```bash
chmod +x cert.sh
./cert.sh
```

### Script Flow

1. **Enter the application/server name** (e.g., `myapp.example.com`).
2. **Choose to renew or create a certificate**:
    - If renewing, specify the directory containing your current certs/keys/CSRs (tab-completion supported).
    - The script scans for `.crt`, `.key`, and `.csr` files, checks expiration, and prompts for renewal.
3. **CA Management**:
    - Use existing CA files, copy them from another location, or create a new CA.
4. **Enter Subject Alternative Names (SANs)**:
    - Specify the number of DNS and IP SANs, then enter each value.
5. **Certificate Generation**:
    - The script generates a new private key, CSR, and signed certificate.
    - Files are saved to your chosen directory.
6. **Transfer and Cleanup**:
    - You are prompted to transfer the files before the script deletes the output directory.

## Example

```text
Enter the name of the application or server (e.g., myapp.example.com): myapp.example.com

Do you want to renew (replace) an existing certificate? (y/n): y

Please specify the directory where your server certificate, key, and CSR are currently saved.
You can use TAB for auto-completion.
Enter the full path to the cert directory (default: /root/output_certs): /etc/myapp/certs/
Found: /etc/myapp/certs/myapp-2025-06-30.crt

The certificate /etc/myapp/certs/myapp-2025-06-30.crt is still valid (expires: Jun 30 05:49:42 2026 GMT).
Do you still want to renew (replace) this certificate? (y/n): n
Certificate renewal cancelled. Exiting.
```

## Requirements

- Bash (Linux or WSL recommended)
- `openssl` installed
- Sufficient permissions to read/write cert/key files and manage CA files

## Notes

- **Do not generate a new CA for each server!** Use the same CA for all your internal certificates.
- Always copy your generated certificates and keys to their final destination before cleanup.
- The script will delete the temporary output directory after you confirm file transfer.

## Credits

- Author: Andy Kukuc
- Script concept and guidance inspired by: [F5 Article K11438](https://my.f5.com/manage/s/article/K11438)

---

**Feel free to modify this script to fit your organization's needs and policies.**