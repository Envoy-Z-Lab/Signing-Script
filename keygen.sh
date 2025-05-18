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

# Define default subject line
default_subject="/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=Android/emailAddress=android@android.com"

# Ask the user if they want to use default values or enter new ones
read -r -p "Do you want to use the default subject line: '$default_subject'? (y/n): " use_default

if [ "$use_default" = "y" ]; then
    subject="$default_subject"
else
    echo "Please enter the following details:"
    read -r -p "Country Shortform (C): " C
    read -r -p "State/Province (ST): " ST
    read -r -p "Location/City (L): " L
    read -r -p "Organization (O): " O
    read -r -p "Organizational Unit (OU): " OU
    read -r -p "Common Name (CN): " CN
    read -r -p "Email Address (emailAddress): " emailAddress

    subject="/C=$C/ST=$ST/L=$L/O=$O/OU=$OU/CN=$CN/emailAddress=$emailAddress"
fi

# Check if make_key exists and is executable
if [ ! -x ./development/tools/make_key ]; then
    echo "Error: make_key tool not found or not executable at ./development/tools/make_key"
    exit 1
fi

# Create certificate directory
mkdir -p ~/.android-certs

# Generate keys with updated list of key types without manual password input
for key_type in releasekey platform shared media networkstack verity otakey testkey cyngn-priv-app sdk_sandbox bluetooth verifiedboot nfc; do
    echo "Generating key: $key_type"
    echo | ./development/tools/make_key "$HOME/.android-certs/$key_type" "$subject"

    # Check if key files exist
    if [[ ! -f "$HOME/.android-certs/$key_type.pk8" || ! -f "$HOME/.android-certs/$key_type.x509.pem" ]]; then
        echo "Error: Key files for '$key_type' were not generated properly."
        exit 1
    fi
done

# Create destination directory
mkdir -p "$destination_dir"

# Move keys to the destination directory
mv "$HOME/.android-certs/"* "$destination_dir"

# Remove the ~/.android-certs directory after moving keys
rm -rf ~/.android-certs

# Write keys.mk file
printf "PRODUCT_DEFAULT_DEV_CERTIFICATE := %s/releasekey\n" "$destination_dir" > "$destination_dir/keys.mk"

# Warn user to back up keys
echo "IMPORTANT: Please make a backup copy of your keys in '$destination_dir' as they are essential for signing your builds."

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

# Set appropriate permissions
chmod -R 755 "$destination_dir"

echo "Key generation and setup completed successfully."
