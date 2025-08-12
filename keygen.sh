#!/bin/bash

# Define destination directory
destination_dir="vendor/private/keys"

# Check if the directory for certificates already exists
if [ -d ~/.android-certs ]; then
    read -r -p "~/.android-certs already exists. Do you want to delete it and proceed? (y/n): " choice
    if [ "$choice" != "y" ]; then
        echo "Exiting script."
        exit 1
    fi
    rm -rf ~/.android-certs
fi

# Default subject (privacy-friendly)
# No real location/email, safe for public release
default_subject="/C=ID/ST=Unknown/L=Unknown/O=PrivateBuild/OU=ROMDev/CN=CustomROM/emailAddress=noreply@example.invalid"

# Ask the user if they want to use the default subject line
read -r -p "Use default privacy-friendly subject line? '$default_subject' (y/n): " use_default

if [ "$use_default" = "y" ]; then
    subject="$default_subject"
else
    echo "Enter your subject details (avoid using personal info!):"
    read -r -p "Country Shortform (C): " C
    read -r -p "State/Province (ST): " ST
    read -r -p "Location/City (L): " L
    read -r -p "Organization (O): " O
    read -r -p "Organizational Unit (OU): " OU
    read -r -p "Common Name (CN): " CN
    # Email is forced to a safe placeholder
    emailAddress="noreply@example.invalid"

    subject="/C=$C/ST=$ST/L=$L/O=$O/OU=$OU/CN=$CN/emailAddress=$emailAddress"
fi

# Check if make_key exists and is executable
if [ ! -x ./development/tools/make_key ]; then
    echo "Error: make_key tool not found or not executable at ./development/tools/make_key"
    exit 1
fi

# Create certificate directory
mkdir -p ~/.android-certs

# List of key types
key_types=(
    releasekey platform shared media networkstack verity otakey
    testkey cyngn-priv-app sdk_sandbox bluetooth verifiedboot nfc
)

# Generate keys
for key_type in "${key_types[@]}"; do
    echo "Generating key: $key_type"
    echo | ./development/tools/make_key "$HOME/.android-certs/$key_type" "$subject"

    if [[ ! -f "$HOME/.android-certs/$key_type.pk8" || ! -f "$HOME/.android-certs/$key_type.x509.pem" ]]; then
        echo "Error: Key files for '$key_type' were not generated properly."
        exit 1
    fi
done

# Create destination directory
mkdir -p "$destination_dir"

# Move keys to destination
mv "$HOME/.android-certs/"* "$destination_dir"
rm -rf ~/.android-certs

# Write keys.mk
printf "PRODUCT_DEFAULT_DEV_CERTIFICATE := %s/releasekey\n" "$destination_dir" > "$destination_dir/keys.mk"

# Generate BUILD.bazel
cat > "$destination_dir/BUILD.bazel" <<EOF
filegroup(
    name = "android_certificate_directory",
    srcs = glob([
        "*.pk8",
        "*.pem",
    ]),
    visibility = ["//visibility:public"],
)
EOF

# Secure permissions for private keys
chmod 600 "$destination_dir"/*.pk8
chmod 644 "$destination_dir"/*.pem
chmod 755 "$destination_dir"

# Warn user
echo "Keys generated in '$destination_dir'."
echo "IMPORTANT: Backup your private keys (*.pk8) securely!"
