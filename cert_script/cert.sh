#!/usr/bin/env bash
# Author: Andy Kukuc
# Script concept and guidance inspired by: https://my.f5.com/manage/s/article/K11438
set -euo pipefail

umask 077

### ─── CONFIGURATION ──────────────────────────────────────────────────────────
# Prompt user for the application/server name and set related variables
read -rp "Enter the name of the application or server (e.g., myapp.example.com): " APP_NAME
COMMON_NAME="$APP_NAME"
CERT_NAME="${APP_NAME}-$(date +%F)"
PROFILE_NAME="clientssl_${APP_NAME}"
VIRTUAL_SERVERS=("vs_${APP_NAME}_www" "vs_${APP_NAME}_api")

WORKDIR="$(mktemp -d)"
CA_BUNDLE_DIR="$WORKDIR/ca_bundle"
OUTPUT_DIR="$(pwd)/output_certs"
mkdir -p "$CA_BUNDLE_DIR"
mkdir -p "$OUTPUT_DIR"
trap 'rm -rf "$WORKDIR"' EXIT
### ────────────────────────────────────────────────────────────────────────────

# --- Certificate Renewal/Rotation Logic (MUST BE BEFORE ANY CERT GENERATION) ---
echo ""
read -rp "Do you want to renew (replace) an existing certificate? (y/n): " do_renew
if [[ "$do_renew" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Please specify the directory where your server certificate, key, and CSR are currently saved."
    echo "You can use TAB for auto-completion."
    read -e -p "Enter the full path to the cert directory (default: $OUTPUT_DIR): " USER_CERT_DIR
    USER_CERT_DIR="${USER_CERT_DIR:-$OUTPUT_DIR}"

    # Scan the directory for cert, key, and CSR files matching the app name
    found_any=0
    for filetype in crt key csr; do
        for file in "$USER_CERT_DIR"/*.$filetype; do
            # Only process if file exists (avoid literal glob if no match)
            [[ -e "$file" ]] || continue
            found_any=1
            echo "Found: $file"
            # For cert, check expiration
            if [[ "$filetype" == "crt" ]]; then
                exp_date=$(openssl x509 -enddate -noout -in "$file" | cut -d= -f2)
                exp_epoch=$(date -d "$exp_date" +%s)
                now_epoch=$(date +%s)
                if (( exp_epoch > now_epoch )); then
                    echo ""
                    echo "The certificate $file is still valid (expires: $exp_date)."
                    read -rp "Do you still want to renew (replace) this certificate? (y/n): " force_renew
                    if [[ ! "$force_renew" =~ ^[Yy]$ ]]; then
                        echo "Certificate renewal cancelled. Exiting."
                        exit 0
                    fi
                else
                    echo "The certificate $file has expired (expired: $exp_date). Proceeding with renewal."
                fi
            fi
        done
    done

    if (( found_any == 1 )); then
        read -rp "Do you want to renew (replace) the existing certificate and key/CSR? (y/n): " renew_cert
        if [[ "$renew_cert" =~ ^[Yy]$ ]]; then
            rm -f "$USER_CERT_DIR"/*.crt "$USER_CERT_DIR"/*.key "$USER_CERT_DIR"/*.csr
            echo "Old certificate, key, and CSR removed (if present). Proceeding with renewal."
        else
            echo "Certificate renewal cancelled. Exiting."
            exit 0
        fi
    else
        echo "No existing certificate, key, or CSR found in $USER_CERT_DIR. Proceeding to generate a new certificate."
    fi
else
    USER_CERT_DIR="$OUTPUT_DIR"
fi
# ------------------------------------------------------------------------------

### ─── CA CONFIGURATION ────────────────────────────────────────────────────────
# Use the same CA for all servers! Do NOT generate a new CA for each server unless prompted below.
CA_CERT="/etc/pki/ca/ca.crt"
CA_KEY="/etc/pki/ca/private/ca.key"
CA_SERIAL="/etc/pki/ca/serial"
CA_CERT_DIR="$(dirname "$CA_CERT")"
CA_KEY_DIR="$(dirname "$CA_KEY")"
CA_SERIAL_DIR="$(dirname "$CA_SERIAL")"
# ------------------------------------------------------------------------------

# Ask if user wants to use or update existing CA files
if [[ -f "$CA_CERT" || -f "$CA_KEY" || -f "$CA_SERIAL" ]]; then
    echo ""
    echo "Existing CA files detected:"
    [[ -f "$CA_CERT" ]] && echo "  $CA_CERT"
    [[ -f "$CA_KEY" ]] && echo "  $CA_KEY"
    [[ -f "$CA_SERIAL" ]] && echo "  $CA_SERIAL"
    read -rp "Do you want to use the existing CA files? (y/n): " use_existing_ca
    if [[ "$use_existing_ca" =~ ^[Yy]$ ]]; then
        echo "Using existing CA files."
    else
        read -rp "Do you want to delete and create a new Root CA? (y/n): " del_ca
        if [[ "$del_ca" =~ ^[Yy]$ ]]; then
            rm -f "$CA_CERT" "$CA_KEY" "$CA_SERIAL"
            echo "Existing CA files deleted."
            # CA files will be created later if missing
        else
            echo "Continuing with existing CA files."
        fi
    fi
fi

# Ensure CA directories exist with correct permissions
for dir in "$CA_CERT_DIR" "$CA_KEY_DIR" "$CA_SERIAL_DIR"; do
    if [[ ! -d "$dir" ]]; then
        echo "Directory $dir does not exist. Creating with 700 permissions."
        mkdir -p "$dir"
        chmod 700 "$dir"
    fi
done

# Check that CA files exist, prompt to copy or create if missing
missing_files=0
for file in "$CA_CERT" "$CA_KEY" "$CA_SERIAL"; do
    if [[ ! -f "$file" ]]; then
        echo "CA file $file not found."
        read -rp "Do you want to copy it from another location now? (y/n): " copy_choice
        if [[ "$copy_choice" =~ ^[Yy]$ ]]; then
            read -rp "Enter the full path to the source file for $file: " src_file
            if [[ -f "$src_file" ]]; then
                cp "$src_file" "$file"
                chmod 600 "$file"
                echo "Copied $src_file to $file"
            else
                echo "Source file $src_file does not exist. Please provide the correct file."
                missing_files=1
            fi
        else
            missing_files=1
        fi
    fi
done

if [[ $missing_files -ne 0 ]]; then
    echo ""
    echo "Some or all CA files are missing."
    read -rp "Do you want to generate a new Root CA now? (y/n): " gen_ca
    if [[ "$gen_ca" =~ ^[Yy]$ ]]; then
        echo "Generating new Root CA..."
        openssl genrsa -out "$CA_KEY" 4096
        chmod 600 "$CA_KEY"
        openssl req -x509 -new -nodes -key "$CA_KEY" -sha512 -days 3650 -out "$CA_CERT"
        chmod 644 "$CA_CERT"
        touch "$CA_SERIAL"
        echo "01" > "$CA_SERIAL"
        chmod 600 "$CA_SERIAL"
        echo "Root CA generated:"
        echo "  Certificate: $CA_CERT"
        echo "  Key:         $CA_KEY"
        echo "  Serial:      $CA_SERIAL"
    else
        echo "ERROR: Required CA files are missing. Please ensure CA_CERT, CA_KEY, and CA_SERIAL are present and accessible."
        exit 1
    fi
fi

# Copy CA files to a bundle directory for transfer
cp "$CA_CERT" "$CA_KEY" "$CA_SERIAL" "$CA_BUNDLE_DIR/"

echo ""
echo "A copy of your CA files has been placed in:"
echo "  $CA_BUNDLE_DIR"
echo "You can now securely copy this folder to another server using:"
echo "  scp -r \"$CA_BUNDLE_DIR\" user@other-server:/desired/path/"
echo ""

# Prompt for SANs
echo "Enter Subject Alternative Names (SANs) for the certificate."
read -rp "How many DNS SANs? " DNS_COUNT
read -rp "How many IP SANs? " IP_COUNT

cat > "$WORKDIR/openssl-san.cnf" <<EOF
[ req ]
default_bits       = 4096
prompt             = yes
default_md         = sha512
distinguished_name = dn
req_extensions     = req_ext

[ dn ]
C  = Country Name (2 letter code)
ST = State or Province Name (full name)
L  = Locality Name (eg, city)
O  = Organization Name (eg, company)
OU = Organizational Unit Name (eg, section)
CN = Common Name (e.g. server FQDN or YOUR name)

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
EOF

for ((i=1; i<=DNS_COUNT; i++)); do
    read -rp "Enter DNS.$i: " dns
    echo "DNS.$i = $dns" >> "$WORKDIR/openssl-san.cnf"
done

for ((i=1; i<=IP_COUNT; i++)); do
    read -rp "Enter IP.$i: " ip
    echo "IP.$i = $ip" >> "$WORKDIR/openssl-san.cnf"
done

echo "🔐 Generating new private key (4096 bits)"
openssl genrsa -out "$WORKDIR/${CERT_NAME}.key" 4096
chmod 600 "$WORKDIR/${CERT_NAME}.key"

echo "📝 Generating CSR with SAN (SHA-512)"
openssl req \
  -new \
  -key "$WORKDIR/${CERT_NAME}.key" \
  -out "$WORKDIR/${CERT_NAME}.csr" \
  -config "$WORKDIR/openssl-san.cnf"

echo "✒️  Signing certificate with internal CA (SHA-512)"
openssl x509 -req \
  -in "$WORKDIR/${CERT_NAME}.csr" \
  -CA "$CA_CERT" \
  -CAkey "$CA_KEY" \
  -CAserial "$CA_SERIAL" \
  -days 365 \
  -out "$WORKDIR/${CERT_NAME}.crt" \
  -extensions req_ext \
  -extfile "$WORKDIR/openssl-san.cnf" \
  -sha512

# Copy server cert, key, and CSR to user-specified directory before cleanup
cp "$WORKDIR/${CERT_NAME}.crt" "$USER_CERT_DIR/"
cp "$WORKDIR/${CERT_NAME}.key" "$USER_CERT_DIR/"
cp "$WORKDIR/${CERT_NAME}.csr" "$USER_CERT_DIR/"

echo "✅ Certificate and key generated locally."

echo ""
echo "Server certificate, key, and CSR have been copied to:"
echo "  $USER_CERT_DIR"
echo ""
echo "A copy remains in the temporary directory until script exit:"
echo "  Certificate: $WORKDIR/${CERT_NAME}.crt"
echo "  Private Key: $WORKDIR/${CERT_NAME}.key"
echo "  CSR:         $WORKDIR/${CERT_NAME}.csr"
echo ""
echo "NOTE: The temporary directory will be deleted when the script exits."
echo ""

echo "🔑 To trust certificates signed by your internal CA, add the following certificate to your trusted root CA store:"
echo "    $CA_CERT"
echo ""
echo "For example, on Windows, double-click the file and import it into the 'Trusted Root Certification Authorities' store."
echo ""
echo "──────────────────────────────────────────────────────────────────────────────"
echo "If you want to generate certificates for other servers using the same CA:"
echo "  1. Securely copy the CA bundle directory to the next server:"
echo "       scp -r \"$CA_BUNDLE_DIR\" user@other-server:/desired/path/"
echo "  2. On the next server, point this script's CA_CERT, CA_KEY, and CA_SERIAL to the copied files."
echo "  3. DO NOT generate a new CA for each server."
echo "  4. Use this script as-is on each server, pointing to the same CA files above."
echo "──────────────────────────────────────────────────────────────────────────────"

echo ""
echo "Please transfer the server certificate, key, and CSR from:"
echo "  $USER_CERT_DIR"
echo "to your target server or desired location."
echo ""
read -rp "Press ENTER after you have transferred the files to clean up the output directory..."

# Clean up the output directory (remove the entire folder)
rm -rf "$OUTPUT_DIR"
echo "The entire output directory ($OUTPUT_DIR) has been removed."