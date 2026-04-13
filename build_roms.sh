#!/bin/bash

# ==========================================
# 1. SSH Setup & Verification
# ==========================================
echo "======================================"
echo "       SSH Setup & Verification       "
echo "======================================"

# Check if SSH key already exists to prevent accidental overwrites
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "Generating new SSH Key..."
    ssh-keygen -t ed25519 -C "raniv2057@gmail.com" -f ~/.ssh/id_ed25519 -N ""
else
    echo "SSH key ~/.ssh/id_ed25519 already exists. Skipping generation."
fi

# Start SSH agent and add key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

echo -e "\n--- Here is your Public SSH Key ---"
cat ~/.ssh/id_ed25519.pub
echo "-----------------------------------"
echo "Please ensure the above key is added to your GitHub account."

# Verification check
read -p "Have you added the key to GitHub? Press 'y' to verify connection: " VERIFY_SSH
if [[ "$VERIFY_SSH" == "y" || "$VERIFY_SSH" == "Y" ]]; then
    echo "Verifying connection..."
    ssh -T git@github.com
else
    echo "Skipping verification. Note: GitHub cloning might fail if the key isn't set up."
fi

# ==========================================
# 2. Main Loop: Project Selection & Build
# ==========================================
while true; do
    echo ""
    echo "======================================"
    echo "           Select Project:            "
    echo "======================================"
    echo "1. axion"
    echo "2. lunaris"
    echo "3. evolution"
    echo "4. infinity"
    echo "5. Exit script"
    read -p "Enter your choice (1-5): " CHOICE

    # Map variables based on selection
    case $CHOICE in
        1)
            PROJECT="axion"
            MANIFEST_BRANCH="axion"
            REPO_INIT="repo init -u https://github.com/AxionAOSP/android.git -b lineage-23.2 --git-lfs"
            BUILD_CMD=". build/envsetup.sh && axion tapas userdebug gms core && ax -br -j\$(nproc --all)"
            ;;
        2)
            PROJECT="lunaris"
            MANIFEST_BRANCH="lunaris"
            REPO_INIT="repo init -u https://github.com/Lunaris-AOSP/android -b 16.2 --git-lfs"
            BUILD_CMD=". build/envsetup.sh && lunch lineage_tapas-bp4a-user && m bacon -j\$(nproc --all)"
            ;;
        3)
            PROJECT="evolution"
            MANIFEST_BRANCH="evolution"
            REPO_INIT="repo init -u https://github.com/Evolution-X/manifest -b bq2 --git-lfs"
            BUILD_CMD=". build/envsetup.sh && lunch lineage_tapas-bp4a-userdebug && m evolution -j\$(nproc --all)"
            ;;
        4)
            PROJECT="infinity"
            MANIFEST_BRANCH="infinity"
            REPO_INIT="repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault"
            BUILD_CMD=". build/envsetup.sh && lunch infinity_tapas-userdebug && m bacon -j\$(nproc --all)"
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            continue
            ;;
    esac

    echo -e "\nStarting setup for $PROJECT..."

    # Create project directory and enter it
    mkdir -p "$PROJECT"
    cd "$PROJECT" || exit

    # Clone local manifests
    echo "Cloning local manifests..."
    mkdir -p .repo/local_manifests
    git clone git@github.com:Rexons-AOSP-Projects/topaz_manifest.git -b "$MANIFEST_BRANCH" .repo/local_manifests

    # Initialize Repo
    echo "Running repo init..."
    $REPO_INIT

    # Sync Repo
    echo "Running repo sync..."
    repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)

    # Clean up specific hardware/qcom-caf folders
    echo "Cleaning up hardware/qcom-caf..."
    if [ -d "hardware/qcom-caf" ]; then
        cd hardware/qcom-caf
        rm -rf msm8953 msm8996 msm8998 sdm660 sdm845 sm8150 sm8250 sm8350 sm8450 sm8450-6.6 sm8550 sm8650 sm8750
        cd - > /dev/null
    else
        echo "hardware/qcom-caf directory not found, skipping cleanup."
    fi

    # Edit Manifest XML files
    echo "Cleaning up XML snippets..."
    # Resolves standard paths or the mani*/sni* wildcard
    SNIPPET_DIR=$(ls -d .repo/manifests/snippets 2>/dev/null || ls -d .repo/mani*/sni* 2>/dev/null)
    
    if [ -n "$SNIPPET_DIR" ] && [ -d "$SNIPPET_DIR" ]; then
        cd "$SNIPPET_DIR" || exit
        
        # We use 'sed' to find any line containing 'hardware/qcom-caf/<board_name>' and delete it from all .xml files
        BOARDS="msm8953 msm8996 msm8998 sdm660 sdm845 sm8150 sm8250 sm8350 sm8450 sm8450-6.6 sm8550 sm8650 sm8750"
        for BOARD in $BOARDS; do
            sed -i "/path=\"hardware\/qcom-caf\/$BOARD/d" *.xml 2>/dev/null || true
        done
        
        cd - > /dev/null
    else
        echo "Snippet directory not found, skipping XML edits."
    fi

    # Build the ROM
    echo "Starting build for $PROJECT..."
    eval "$BUILD_CMD"
    
    echo -e "\nBuild sequence for $PROJECT completed!"
    
    # Go back to the root directory so the menu can cycle again properly
    cd ..
done
