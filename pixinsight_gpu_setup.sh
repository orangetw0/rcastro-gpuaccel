#!/bin/bash

################################################################################
# PixInsight GPU Acceleration Setup Script for Linux (Ubuntu/Kubuntu)
# 
# This script installs CUDA 12.8, cuDNN 8.9.7, and TensorFlow 2.15.0 GPU libraries
# to enable GPU acceleration for RC Astro tools (StarXTerminator, NoiseXTerminator,
# BlurXTerminator) and StarNet++ in PixInsight.
#
# Features:
# - Automatic root privilege handling
# - Complete installation with verification
# - Backup of original PixInsight libraries
# - Easy rollback/restore functionality
# - Clean uninstallation option
# - NVIDIA driver verification
#
# Usage: ./pixinsight_gpu_setup.sh [option]
# Options: install, restore, uninstall, verify, menu (default)
################################################################################

set -e  # Exit on error

# Configuration Variables
CUDA_VERSION="12.8.0"
CUDA_SHORT="12-8"
CUDA_INSTALLER="cuda_${CUDA_VERSION}_570.86.10_linux.run"
CUDA_URL="https://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/local_installers/${CUDA_INSTALLER}"

CUDNN_VERSION="8.9.7.29"
CUDNN_CUDA="12"
CUDNN_FILE="cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz"
CUDNN_URL="https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/${CUDNN_FILE}"

TENSORFLOW_VERSION="2.15.0"
TENSORFLOW_FILE="libtensorflow-gpu-linux-x86_64-${TENSORFLOW_VERSION}.tar.gz"
TENSORFLOW_URL="https://storage.googleapis.com/tensorflow/libtensorflow/${TENSORFLOW_FILE}"

PIXINSIGHT_DIR="/opt/PixInsight"
PIXINSIGHT_LIB_DIR="${PIXINSIGHT_DIR}/bin/lib"
BACKUP_DIR="/opt/pixinsight_gpu_backup"
DOWNLOAD_DIR="/tmp/pixinsight_gpu_downloads"
INSTALL_LOG="${BACKUP_DIR}/install.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
    [ -d "$BACKUP_DIR" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$INSTALL_LOG" || true
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    [ -d "$BACKUP_DIR" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $1" >> "$INSTALL_LOG" || true
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    [ -d "$BACKUP_DIR" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$INSTALL_LOG" || true
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    [ -d "$BACKUP_DIR" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$INSTALL_LOG" || true
}

# Check if running as root, if not, re-execute with sudo
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}[WARN]${NC} This script requires root privileges."
        echo -e "${YELLOW}[WARN]${NC} Re-launching with sudo. You may be prompted for your password..."
        echo ""

        # Re-execute with sudo, preserving environment
        # exec replaces current process, so this will not return on success
        exec sudo -E bash "$0" "$@"

        # If we reach here, exec failed
        echo -e "${RED}[ERROR]${NC} Failed to obtain root privileges."
        echo -e "${RED}[ERROR]${NC} Please run this script with: sudo $0 $*"
        exit 1
    fi
}

# Create necessary directories
setup_directories() {
    log "Creating necessary directories..."
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$DOWNLOAD_DIR"
    chmod 755 "$BACKUP_DIR"
    touch "$INSTALL_LOG"
}

# Check for NVIDIA GPU
check_nvidia_gpu() {
    log "Checking for NVIDIA GPU..."
    if ! lspci | grep -i nvidia > /dev/null 2>&1; then
        error "No NVIDIA GPU detected. This script is for NVIDIA GPUs only."
        return 1
    fi
    
    local gpu_info=$(lspci | grep -i nvidia | grep -i vga | head -n1)
    success "NVIDIA GPU detected: $gpu_info"
    return 0
}

# Check NVIDIA driver
check_nvidia_driver() {
    log "Checking NVIDIA driver installation..."
    
    if ! command -v nvidia-smi &> /dev/null; then
        error "NVIDIA driver not found. Please install NVIDIA proprietary drivers first."
        echo "  Run: sudo ubuntu-drivers autoinstall"
        return 1
    fi
    
    local driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)
    success "NVIDIA driver installed: version $driver_version"
    
    # Check if nouveau is loaded
    if lsmod | grep -q nouveau; then
        error "Nouveau driver is loaded. Please disable it before proceeding."
        echo "  Add 'blacklist nouveau' to /etc/modprobe.d/blacklist-nouveau.conf"
        return 1
    fi
    
    return 0
}

# Check PixInsight installation
check_pixinsight() {
    log "Checking PixInsight installation..."
    
    if [ ! -d "$PIXINSIGHT_DIR" ]; then
        error "PixInsight not found at $PIXINSIGHT_DIR"
        return 1
    fi
    
    if [ ! -d "$PIXINSIGHT_LIB_DIR" ]; then
        error "PixInsight library directory not found at $PIXINSIGHT_LIB_DIR"
        return 1
    fi
    
    success "PixInsight installation found at $PIXINSIGHT_DIR"
    return 0
}

# Install system dependencies
install_dependencies() {
    log "Installing system dependencies..."
    
    apt-get update
    apt-get install -y \
        build-essential \
        wget \
        curl \
        git \
        pkg-config \
        software-properties-common \
        gnupg2 \
        ca-certificates \
        gcc-11 \
        g++-11
    
    success "System dependencies installed"
}

################################################################################
# CUDA Installation
################################################################################

install_cuda() {
    log "Installing CUDA Toolkit ${CUDA_VERSION}..."
    
    # Check if CUDA is already installed
    if [ -d "/usr/local/cuda-12.8" ]; then
        warn "CUDA 12.8 appears to be already installed at /usr/local/cuda-12.8"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Skipping CUDA installation"
            return 0
        fi
    fi
    
    cd "$DOWNLOAD_DIR"
    
    # Download CUDA installer if not present
    if [ ! -f "$CUDA_INSTALLER" ]; then
        log "Downloading CUDA installer..."
        wget -q --show-progress "$CUDA_URL" || {
            error "Failed to download CUDA installer"
            return 1
        }
    fi
    
    log "Running CUDA installer (this may take several minutes)..."
    chmod +x "$CUDA_INSTALLER"
    
    # Run CUDA installer silently
    ./"$CUDA_INSTALLER" --silent --toolkit --toolkitpath=/usr/local/cuda-12.8 --no-opengl-libs || {
        error "CUDA installation failed"
        return 1
    }
    
    # Create symbolic link
    if [ ! -L "/usr/local/cuda" ] || [ "$(readlink /usr/local/cuda)" != "cuda-12.8" ]; then
        ln -sf /usr/local/cuda-12.8 /usr/local/cuda
    fi
    
    # Set up environment variables
    log "Configuring CUDA environment variables..."
    
    if ! grep -q "CUDA 12.8" /etc/profile.d/cuda.sh 2>/dev/null; then
        cat > /etc/profile.d/cuda.sh << 'EOF'
# CUDA 12.8 Environment Variables
export CUDA_HOME=/usr/local/cuda-12.8
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
EOF
        chmod +x /etc/profile.d/cuda.sh
    fi
    
    # Source the environment
    export CUDA_HOME=/usr/local/cuda-12.8
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
    
    # Verify installation
    if [ -f "/usr/local/cuda-12.8/bin/nvcc" ]; then
        local nvcc_version=$(/usr/local/cuda-12.8/bin/nvcc --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
        success "CUDA installed successfully: version $nvcc_version"
        return 0
    else
        error "CUDA installation verification failed"
        return 1
    fi
}

################################################################################
# cuDNN Installation
################################################################################

install_cudnn() {
    log "Installing cuDNN ${CUDNN_VERSION}..."
    
    cd "$DOWNLOAD_DIR"
    
    # Download cuDNN if not present
    if [ ! -f "$CUDNN_FILE" ]; then
        log "Downloading cuDNN..."
        log "Note: If download fails, you may need to download manually from:"
        log "https://developer.nvidia.com/rdp/cudnn-archive"
        
        wget -q --show-progress "$CUDNN_URL" || {
            warn "Automatic download failed. Please download manually:"
            echo "  1. Visit: https://developer.nvidia.com/rdp/cudnn-archive"
            echo "  2. Download: cuDNN v8.9.7 for CUDA 11.x (Linux x86_64)"
            echo "  3. Place file in: $DOWNLOAD_DIR"
            echo "  4. Re-run this script"
            return 1
        }
    fi
    
    log "Extracting and installing cuDNN..."
    tar -xf "$CUDNN_FILE"
    
    local cudnn_dir=$(find . -maxdepth 1 -name "cudnn-*" -type d | head -n1)
    
    if [ -z "$cudnn_dir" ]; then
        error "Failed to extract cuDNN"
        return 1
    fi
    
    # Copy cuDNN files to CUDA directory
    cp -P "$cudnn_dir"/include/* /usr/local/cuda-12.8/include/
    cp -P "$cudnn_dir"/lib/* /usr/local/cuda-12.8/lib64/
    
    # Set permissions
    chmod a+r /usr/local/cuda-12.8/include/cudnn*.h
    chmod a+r /usr/local/cuda-12.8/lib64/libcudnn*
    
    # Verify installation
    if [ -f "/usr/local/cuda-12.8/include/cudnn.h" ]; then
        success "cuDNN installed successfully"
        return 0
    else
        error "cuDNN installation verification failed"
        return 1
    fi
}

################################################################################
# TensorFlow Installation
################################################################################

install_tensorflow() {
    log "Installing TensorFlow GPU ${TENSORFLOW_VERSION}..."
    
    cd "$DOWNLOAD_DIR"
    
    # Download TensorFlow if not present
    if [ ! -f "$TENSORFLOW_FILE" ]; then
        log "Downloading TensorFlow GPU library..."
        wget -q --show-progress "$TENSORFLOW_URL" || {
            error "Failed to download TensorFlow"
            return 1
        }
    fi
    
    log "Installing TensorFlow to /usr/local..."
    tar -xzf "$TENSORFLOW_FILE" -C /usr/local
    
    # Update library cache
    ldconfig /usr/local/lib
    
    # Verify installation
    if [ -f "/usr/local/lib/libtensorflow.so.2" ]; then
        success "TensorFlow GPU installed successfully"
        return 0
    else
        error "TensorFlow installation verification failed"
        return 1
    fi
}

################################################################################
# PixInsight Configuration
################################################################################

backup_pixinsight_libs() {
    log "Backing up original PixInsight TensorFlow libraries..."
    
    if [ ! -d "$BACKUP_DIR/pixinsight_libs" ]; then
        mkdir -p "$BACKUP_DIR/pixinsight_libs"
        
        # Backup all libtensorflow files
        if ls "$PIXINSIGHT_LIB_DIR"/libtensorflow* 1> /dev/null 2>&1; then
            cp -a "$PIXINSIGHT_LIB_DIR"/libtensorflow* "$BACKUP_DIR/pixinsight_libs/" || {
                error "Failed to backup PixInsight libraries"
                return 1
            }
            
            # Save list of backed up files
            ls -1 "$BACKUP_DIR/pixinsight_libs" > "$BACKUP_DIR/backed_up_files.txt"
            
            success "Original libraries backed up to $BACKUP_DIR/pixinsight_libs"
        else
            warn "No TensorFlow libraries found in PixInsight to backup"
        fi
    else
        warn "Backup already exists at $BACKUP_DIR/pixinsight_libs"
    fi
    
    return 0
}

configure_pixinsight() {
    log "Configuring PixInsight to use GPU-enabled TensorFlow..."
    
    if [ ! -d "$PIXINSIGHT_LIB_DIR" ]; then
        error "PixInsight library directory not found"
        return 1
    fi
    
    # Backup first
    backup_pixinsight_libs || return 1
    
    # Move PixInsight's TensorFlow libraries out of the way
    log "Moving PixInsight's original TensorFlow libraries..."
    if ls "$PIXINSIGHT_LIB_DIR"/libtensorflow* 1> /dev/null 2>&1; then
        mkdir -p "$PIXINSIGHT_LIB_DIR/original_tf_libs"
        mv "$PIXINSIGHT_LIB_DIR"/libtensorflow* "$PIXINSIGHT_LIB_DIR/original_tf_libs/" || {
            error "Failed to move PixInsight libraries"
            return 1
        }
        
        # Save the move location
        echo "$PIXINSIGHT_LIB_DIR/original_tf_libs" > "$BACKUP_DIR/moved_location.txt"
        
        success "Original libraries moved to $PIXINSIGHT_LIB_DIR/original_tf_libs"
    else
        warn "No TensorFlow libraries found to move"
    fi
    
    # Update PixInsight startup script to use system TensorFlow
    local pixinsight_sh="$PIXINSIGHT_DIR/PixInsight.sh"
    
    if [ -f "$pixinsight_sh" ]; then
        log "Updating PixInsight startup script..."
        
        # Backup the startup script
        if [ ! -f "$BACKUP_DIR/PixInsight.sh.backup" ]; then
            cp "$pixinsight_sh" "$BACKUP_DIR/PixInsight.sh.backup"
        fi
        
        # Add LD_LIBRARY_PATH if not already present
        if ! grep -q "LD_LIBRARY_PATH=/usr/local/lib" "$pixinsight_sh"; then
            sed -i '/^export LD_LIBRARY_PATH=/d' "$pixinsight_sh"
            sed -i '1a export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' "$pixinsight_sh"
            success "Updated PixInsight startup script"
        else
            log "PixInsight startup script already configured"
        fi
    fi
    
    success "PixInsight configuration complete"
    return 0
}

################################################################################
# Restore Functions
################################################################################

restore_pixinsight() {
    log "Restoring original PixInsight libraries..."
    
    if [ ! -d "$BACKUP_DIR/pixinsight_libs" ]; then
        error "No backup found at $BACKUP_DIR/pixinsight_libs"
        return 1
    fi
    
    # Restore from moved location first
    if [ -f "$BACKUP_DIR/moved_location.txt" ]; then
        local moved_location=$(cat "$BACKUP_DIR/moved_location.txt")
        if [ -d "$moved_location" ]; then
            log "Restoring from $moved_location..."
            cp -a "$moved_location"/* "$PIXINSIGHT_LIB_DIR/" || {
                error "Failed to restore from moved location"
                return 1
            }
            rm -rf "$moved_location"
        fi
    fi
    
    # Also restore from backup
    if [ -f "$BACKUP_DIR/backed_up_files.txt" ]; then
        log "Restoring backed up files..."
        cp -a "$BACKUP_DIR/pixinsight_libs"/* "$PIXINSIGHT_LIB_DIR/" || {
            error "Failed to restore backup files"
            return 1
        }
    fi
    
    # Restore startup script
    if [ -f "$BACKUP_DIR/PixInsight.sh.backup" ]; then
        log "Restoring PixInsight startup script..."
        cp "$BACKUP_DIR/PixInsight.sh.backup" "$PIXINSIGHT_DIR/PixInsight.sh"
    fi
    
    success "Original PixInsight libraries restored"
    return 0
}

################################################################################
# Uninstall Functions
################################################################################

uninstall_all() {
    log "Uninstalling GPU acceleration components..."
    
    # Restore PixInsight first
    if [ -d "$BACKUP_DIR" ]; then
        restore_pixinsight
    fi
    
    # Remove TensorFlow
    log "Removing TensorFlow libraries from /usr/local..."
    rm -f /usr/local/lib/libtensorflow*
    rm -f /usr/local/include/tensorflow
    ldconfig
    
    # Remove CUDA (optional - user may want to keep for other applications)
    read -p "Do you want to remove CUDA 12.8? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Removing CUDA 12.8..."
        rm -rf /usr/local/cuda-12.8
        rm -f /usr/local/cuda
        rm -f /etc/profile.d/cuda.sh
    else
        log "Keeping CUDA installation"
    fi
    
    # Remove downloads
    read -p "Do you want to remove downloaded files from $DOWNLOAD_DIR? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Removing downloaded files..."
        rm -rf "$DOWNLOAD_DIR"
    fi
    
    # Keep or remove backup
    read -p "Do you want to remove backup directory $BACKUP_DIR? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Removing backup directory..."
        rm -rf "$BACKUP_DIR"
    else
        log "Backup directory preserved at $BACKUP_DIR"
    fi
    
    success "Uninstallation complete"
}

################################################################################
# Verification Functions
################################################################################

verify_installation() {
    log "Verifying GPU acceleration setup..."
    echo
    
    local errors=0
    
    # Check NVIDIA driver
    echo -n "Checking NVIDIA driver... "
    if command -v nvidia-smi &> /dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        ((errors++))
    fi
    
    # Check CUDA
    echo -n "Checking CUDA installation... "
    if [ -d "/usr/local/cuda-12.8" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        ((errors++))
    fi
    
    # Check cuDNN
    echo -n "Checking cuDNN installation... "
    if [ -f "/usr/local/cuda-12.8/include/cudnn.h" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        ((errors++))
    fi
    
    # Check TensorFlow
    echo -n "Checking TensorFlow GPU library... "
    if [ -f "/usr/local/lib/libtensorflow.so.2" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        ((errors++))
    fi
    
    # Check PixInsight configuration
    echo -n "Checking PixInsight library configuration... "
    if [ -d "$PIXINSIGHT_LIB_DIR/original_tf_libs" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}WARNING${NC} - Original libs not moved"
    fi
    
    # Check backup
    echo -n "Checking backup integrity... "
    if [ -d "$BACKUP_DIR/pixinsight_libs" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}WARNING${NC} - No backup found"
    fi
    
    echo
    if [ $errors -eq 0 ]; then
        success "All verification checks passed!"
        echo
        echo "GPU acceleration should now be enabled in PixInsight."
        echo "Please restart PixInsight to use GPU-accelerated tools."
    else
        error "$errors verification checks failed"
        return 1
    fi
    
    return 0
}

################################################################################
# Full Installation
################################################################################

full_install() {
    log "Starting full GPU acceleration installation..."
    echo
    
    setup_directories
    
    # Pre-flight checks
    check_nvidia_gpu || return 1
    check_nvidia_driver || return 1
    check_pixinsight || return 1
    
    # Install components
    install_dependencies || return 1
    install_cuda || return 1
    install_cudnn || return 1
    install_tensorflow || return 1
    configure_pixinsight || return 1
    
    echo
    success "Installation complete!"
    echo
    echo "Next steps:"
    echo "  1. Restart your system (or source /etc/profile.d/cuda.sh)"
    echo "  2. Launch PixInsight"
    echo "  3. Test with StarXTerminator or other RC Astro tools"
    echo
    echo "To verify the installation, run: sudo $0 verify"
    echo "To restore original setup, run: sudo $0 restore"
    echo "To uninstall everything, run: sudo $0 uninstall"
    echo
}

################################################################################
# Interactive Menu
################################################################################

show_menu() {
    clear
    echo "============================================================"
    echo "  PixInsight GPU Acceleration Setup Script"
    echo "============================================================"
    echo
    echo "1. Install GPU acceleration (full installation)"
    echo "2. Verify installation"
    echo "3. Restore original PixInsight libraries"
    echo "4. Uninstall GPU acceleration"
    echo "5. Check system requirements"
    echo "6. View installation log"
    echo "7. Exit"
    echo
    echo -n "Select an option [1-7]: "
}

interactive_menu() {
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                echo
                full_install
                echo
                read -p "Press Enter to continue..."
                ;;
            2)
                echo
                verify_installation
                echo
                read -p "Press Enter to continue..."
                ;;
            3)
                echo
                restore_pixinsight
                echo
                read -p "Press Enter to continue..."
                ;;
            4)
                echo
                uninstall_all
                echo
                read -p "Press Enter to continue..."
                ;;
            5)
                echo
                check_nvidia_gpu
                check_nvidia_driver
                check_pixinsight
                echo
                read -p "Press Enter to continue..."
                ;;
            6)
                echo
                if [ -f "$INSTALL_LOG" ]; then
                    less "$INSTALL_LOG"
                else
                    echo "No log file found"
                fi
                ;;
            7)
                echo
                log "Exiting..."
                exit 0
                ;;
            *)
                echo
                error "Invalid option. Please select 1-7."
                sleep 2
                ;;
        esac
    done
}

################################################################################
# Main Script
################################################################################

main() {
    # Check for root privileges
    check_root "$@"
    
    # Parse command line arguments
    case "${1:-menu}" in
        install)
            full_install
            ;;
        restore)
            restore_pixinsight
            ;;
        uninstall)
            uninstall_all
            ;;
        verify)
            verify_installation
            ;;
        menu|"")
            interactive_menu
            ;;
        help|--help|-h)
            echo "Usage: $0 [option]"
            echo
            echo "Options:"
            echo "  install    - Install GPU acceleration"
            echo "  restore    - Restore original PixInsight libraries"
            echo "  uninstall  - Remove GPU acceleration"
            echo "  verify     - Verify installation"
            echo "  menu       - Show interactive menu (default)"
            echo "  help       - Show this help message"
            ;;
        *)
            error "Unknown option: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
