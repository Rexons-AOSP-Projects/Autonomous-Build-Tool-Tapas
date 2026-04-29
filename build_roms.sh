#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' 

print_header() {
    echo -e "\n${CYAN}${BOLD}======================================================${NC}"
    echo -e "${CYAN}${BOLD}  $1 ${NC}"
    echo -e "${CYAN}${BOLD}======================================================${NC}\n"
}

info() { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✔]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✖]${NC} $1"; }

clear
print_header "SSH Setup & Verification"

# Check if SSH key exists. If not, generate, prompt, and verify. If it does, load it and auto-verify.
if [ ! -f ~/.ssh/id_ed25519 ]; then
    info "Generating new SSH Key..."
    ssh-keygen -t ed25519 -C "raniv2057@gmail.com" -f ~/.ssh/id_ed25519 -N "" >/dev/null 2>&1
    success "New SSH key generated."

    info "Starting SSH agent and adding key..."
    eval "$(ssh-agent -s)" >/dev/null 2>&1
    ssh-add ~/.ssh/id_ed25519 >/dev/null 2>&1

    echo -e "\n${YELLOW}--- Here is your Public SSH Key ---${NC}"
    cat ~/.ssh/id_ed25519.pub
    echo -e "${YELLOW}-----------------------------------${NC}\n"
    warn "Please ensure the above key is added to your GitHub account."

    read -p "$(echo -e ${BOLD}Have you added the key to GitHub? Press 'y' to verify connection: ${NC})" VERIFY_SSH
    if [[ "$VERIFY_SSH" == "y" || "$VERIFY_SSH" == "Y" ]]; then
        info "Verifying connection to GitHub..."
        ssh -T git@github.com
    else
        warn "Skipping verification. Note: GitHub cloning might fail if the key isn't set up."
    fi
    sleep 2
else
    success "SSH key ~/.ssh/id_ed25519 already exists. Skipping generation."
    
    info "Starting SSH agent and loading existing key..."
    eval "$(ssh-agent -s)" >/dev/null 2>&1
    ssh-add ~/.ssh/id_ed25519 >/dev/null 2>&1
    
    info "Testing connection to GitHub with existing key..."
    ssh -T git@github.com
    sleep 2
fi

print_header "Git Global Configuration"

git config --global user.name "Kolass2004"
git config --global user.email "raniv2057@gmail.com"

success "Git global user set to: $(git config --global user.name)"
success "Git global email set to: $(git config --global user.email)"
sleep 2

# Helper function to prevent repeating project variables
set_project_env() {
    case $1 in
        1)
            PROJECT="axion"
            MANIFEST_BRANCH="axion"
            REPO_INIT="repo init -u https://github.com/AxionAOSP/android.git -b lineage-23.2 --git-lfs"
            BUILD_CMD=". build/envsetup.sh && axion tapas userdebug core && ax -br -j\$(nproc --all)"
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
            PROJECT="mist"
            MANIFEST_BRANCH="mist"
            REPO_INIT="repo init -u https://github.com/Project-Mist-OS/manifest -b 16.2 --git-lfs"
            BUILD_CMD=". build/envsetup.sh && mistify tapas userdebug && mist b"
            ;;
    esac
}

while true; do
    clear
    print_header "Android ROM Build Menu"
    
    echo -e "  ${BOLD}1.${NC} Axion"
    echo -e "  ${BOLD}2.${NC} Lunaris"
    echo -e "  ${BOLD}3.${NC} Evolution"
    echo -e "  ${BOLD}4.${NC} Infinity"
    echo -e "  ${BOLD}5.${NC} Mist"
    echo -e "  ${BOLD}6.${NC} Restart (Run build command only)"
    echo -e "  ${BOLD}7.${NC} ${RED}Exit Script${NC}"
    echo ""
    read -p "$(echo -e ${BOLD}Enter your choice [1-7]: ${NC})" CHOICE

    SKIP_SYNC=false

    case $CHOICE in
        1|2|3|4|5)
            set_project_env "$CHOICE"
            ;;
        6)
            echo -e "\n${CYAN}Which project would you like to restart?${NC}"
            echo -e "  1. Axion\n  2. Lunaris\n  3. Evolution\n  4. Infinity\n  5. Mist"
            read -p "$(echo -e ${BOLD}Enter choice [1-5]: ${NC})" RESTART_CHOICE
            
            if [[ "$RESTART_CHOICE" =~ ^[1-5]$ ]]; then
                set_project_env "$RESTART_CHOICE"
                SKIP_SYNC=true
            else
                error "Invalid choice."
                sleep 2
                continue
            fi
            ;;
        7)
            success "Exiting script. Have a great day!"
            exit 0
            ;;
        *)
            error "Invalid choice. Please try again."
            sleep 2
            continue
            ;;
    esac

    # If user chose 'Restart', skip straight to the build command
    if [ "$SKIP_SYNC" = true ]; then
        clear
        print_header "Restarting Build: $PROJECT"
        
        if [ ! -d "$PROJECT" ]; then
            error "Directory '$PROJECT' does not exist. Please run a full sync (Options 1-5) first."
            sleep 3
            continue
        fi
        
        cd "$PROJECT" || exit
        info "Running build command..."
        eval "$BUILD_CMD"
        
        print_header "Build Sequence Finished"
        success "The restart process for $PROJECT is complete!"
        
        echo ""
        read -p "$(echo -e ${BOLD}Press Enter to return to the main menu...${NC})"
        cd ..
        continue
    fi

    # ---------------------------------------------------------
    # Normal Init, Sync, and Cleanup Sequence (Options 1-5)
    # ---------------------------------------------------------

    clear
    print_header "Initializing $PROJECT"

    info "Setting up workspace..."
    mkdir -p "$PROJECT"
    cd "$PROJECT" || exit

    info "Cloning local manifests..."
    mkdir -p .repo/local_manifests
    git clone git@github.com:Rexons-AOSP-Projects/topaz_manifest.git -b "$MANIFEST_BRANCH" .repo/local_manifests

    info "Running repo init..."
    $REPO_INIT

    info "Running repo sync..."
    repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)

    print_header "Hardware Cleanup"
    if [ -d "hardware/qcom-caf" ]; then
        info "Cleaning up hardware/qcom-caf..."
        cd hardware/qcom-caf
        rm -rf msm8953 msm8996 msm8998 sdm660 sdm845 sm8150 sm8250 sm8350 sm8450 sm8450-6.6 sm8550 sm8650 sm8750
        cd - > /dev/null
        success "Cleanup complete."
    else
        warn "hardware/qcom-caf directory not found, skipping cleanup."
    fi

    info "Cleaning up XML snippets..."
    SNIPPET_DIR=$(ls -d .repo/manifests/snippets 2>/dev/null || ls -d .repo/mani*/sni* 2>/dev/null)
    
    if [ -n "$SNIPPET_DIR" ] && [ -d "$SNIPPET_DIR" ]; then
        cd "$SNIPPET_DIR" || exit
        
        BOARDS="msm8953 msm8996 msm8998 sdm660 sdm845 sm8150 sm8250 sm8350 sm8450 sm8450-6.6 sm8550 sm8650 sm8750"
        for BOARD in $BOARDS; do
            sed -i "/path=\"hardware\/qcom-caf\/$BOARD/d" *.xml 2>/dev/null || true
        done
        
        cd - > /dev/null
        success "XML snippets updated."
    else
        warn "Snippet directory not found, skipping XML edits."
    fi

    print_header "Starting Build: $PROJECT"
    eval "$BUILD_CMD"
    
    print_header "Build Sequence Finished"
    success "The process for $PROJECT is complete!"
    
    echo ""
    read -p "$(echo -e ${BOLD}Press Enter to return to the main menu...${NC})"
    
    cd ..
done
