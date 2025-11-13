# PixInsight GPU Acceleration Setup Script

A comprehensive bash script to install and configure GPU acceleration for PixInsight on Linux (Ubuntu/Kubuntu) with NVIDIA GPUs.

## Overview

This script automates the installation of CUDA 12.8, cuDNN 8.9.7, and TensorFlow 2.15.0 GPU libraries to enable GPU acceleration for RC Astro tools (StarXTerminator, NoiseXTerminator, BlurXTerminator) and StarNet++ in PixInsight.

## Features

✅ **Automatic Installation**: One-command setup of all required components  
✅ **Root Privilege Handling**: Automatically requests sudo when needed  
✅ **Safety First**: Backs up all original PixInsight libraries before modification  
✅ **Easy Rollback**: Restore original configuration with a single command  
✅ **Clean Removal**: Complete uninstallation option  
✅ **Verification**: Built-in checks to verify successful installation  
✅ **Interactive Menu**: User-friendly menu for all operations  
✅ **Logging**: Detailed installation log for troubleshooting  

## System Requirements

### Hardware
- NVIDIA GPU with CUDA compute capability 3.5 or higher
- At least 4GB GPU memory (6GB+ recommended for full AI models)
- 10GB free disk space for downloads and installation

### Software
- Ubuntu 22.04 LTS or Kubuntu 22.04 LTS (or newer)
- NVIDIA proprietary drivers installed (recommended: 520+)
- PixInsight for Linux already installed

### Verified Compatible GPUs
- NVIDIA GeForce RTX series (2060, 3060, 4060, etc.)
- NVIDIA GeForce GTX 1660 and newer
- NVIDIA Quadro series
- NVIDIA Tesla series

## Pre-Installation Steps

### 1. Install NVIDIA Drivers

If you haven't already installed NVIDIA drivers:

```bash
# Check for recommended drivers
ubuntu-drivers devices

# Install recommended drivers automatically
sudo ubuntu-drivers autoinstall

# Reboot
sudo reboot
```

Verify driver installation:
```bash
nvidia-smi
```

### 2. Disable Nouveau Driver (if active)

The nouveau driver conflicts with NVIDIA proprietary drivers:

```bash
# Check if nouveau is loaded
lsmod | grep nouveau

# If loaded, disable it:
sudo bash -c "echo blacklist nouveau > /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo bash -c "echo options nouveau modeset=0 >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo update-initramfs -u
sudo reboot
```

### 3. Install PixInsight

Download and install PixInsight from [https://pixinsight.com/downloads/](https://pixinsight.com/downloads/)

```bash
# Extract downloaded archive
tar -xf PI-linux-x64-*.tar.xz

# Run installer
sudo ./installer
```

## Installation

### Quick Start

1. **Download the script:**
```bash
wget https://your-script-location/pixinsight_gpu_setup.sh
# Or clone from repository
```

2. **Make it executable:**
```bash
chmod +x pixinsight_gpu_setup.sh
```

3. **Run the script:**
```bash
# Interactive menu (recommended for first-time users)
sudo ./pixinsight_gpu_setup.sh

# Or direct installation
sudo ./pixinsight_gpu_setup.sh install
```

### Installation Process

The script will:

1. **Verify Prerequisites**
   - Check for NVIDIA GPU
   - Verify NVIDIA driver installation
   - Confirm PixInsight installation
   - Check that nouveau driver is not active

2. **Install System Dependencies**
   - Build tools (gcc, g++, make)
   - Download utilities (wget, curl)

3. **Install CUDA Toolkit 12.8**
   - Downloads and installs CUDA 12.8.0
   - Configures environment variables
   - Creates symbolic links

4. **Install cuDNN 8.9.7**
   - Downloads cuDNN 8.9.7 for CUDA 12
   - Extracts and installs to CUDA directory
   - Sets proper permissions

5. **Install TensorFlow GPU 2.15.0**
   - Downloads TensorFlow C API with GPU support
   - Installs to /usr/local
   - Updates library cache

6. **Configure PixInsight**
   - **Backs up** original TensorFlow libraries
   - Moves PixInsight's CPU-only libraries aside
   - Updates startup script to use GPU libraries

## Usage

### Interactive Menu

Run without arguments to access the interactive menu:

```bash
sudo ./pixinsight_gpu_setup.sh
```

Menu options:
1. **Install GPU acceleration** - Full installation
2. **Verify installation** - Check if everything is working
3. **Restore original libraries** - Rollback to CPU-only
4. **Uninstall GPU acceleration** - Complete removal
5. **Check system requirements** - Pre-installation checks
6. **View installation log** - Review detailed logs
7. **Exit**

### Command Line Options

```bash
# Full installation
sudo ./pixinsight_gpu_setup.sh install

# Verify installation
sudo ./pixinsight_gpu_setup.sh verify

# Restore original PixInsight libraries
sudo ./pixinsight_gpu_setup.sh restore

# Uninstall everything
sudo ./pixinsight_gpu_setup.sh uninstall

# Show help
./pixinsight_gpu_setup.sh help
```

## After Installation

### 1. Restart Your System

For environment variables to take effect:
```bash
sudo reboot
```

Or source the CUDA environment:
```bash
source /etc/profile.d/cuda.sh
```

### 2. Launch PixInsight

Start PixInsight normally:
```bash
/opt/PixInsight/PixInsight.sh
```

### 3. Test GPU Acceleration

1. Open an image in PixInsight
2. Run StarXTerminator, NoiseXTerminator, or BlurXTerminator
3. Processing should be significantly faster
4. Monitor GPU usage with `nvidia-smi` in another terminal

### 4. Verify GPU Usage

While processing, open another terminal and run:
```bash
watch -n 1 nvidia-smi
```

You should see:
- GPU utilization percentage increase
- GPU memory usage increase
- Power consumption increase

## File Locations

### Installation Directories
- **CUDA**: `/usr/local/cuda-12.8/`
- **TensorFlow**: `/usr/local/lib/libtensorflow*`
- **PixInsight**: `/opt/PixInsight/`

### Backup Locations
- **Backup directory**: `/opt/pixinsight_gpu_backup/`
- **Original libraries**: `/opt/pixinsight_gpu_backup/pixinsight_libs/`
- **Startup script backup**: `/opt/pixinsight_gpu_backup/PixInsight.sh.backup`
- **Installation log**: `/opt/pixinsight_gpu_backup/install.log`

### Moved Libraries
- **Original PixInsight TF libs**: `/opt/PixInsight/bin/lib/original_tf_libs/`

### Downloaded Files
- **Download cache**: `/tmp/pixinsight_gpu_downloads/`

## Troubleshooting

### PixInsight Still Uses CPU

**Check library configuration:**
```bash
# Verify GPU libraries are accessible
ls -l /usr/local/lib/libtensorflow*

# Check if original libs were moved
ls -l /opt/PixInsight/bin/lib/original_tf_libs/

# Review installation log
sudo less /opt/pixinsight_gpu_backup/install.log
```

**Verify PixInsight can see GPU libraries:**
```bash
# Check PixInsight startup script
cat /opt/PixInsight/PixInsight.sh | grep LD_LIBRARY_PATH
```

### CUDA Not Found

**Source environment variables:**
```bash
source /etc/profile.d/cuda.sh
echo $CUDA_HOME
echo $PATH | grep cuda
```

### Nouveau Driver Conflicts

If you see nouveau driver errors:
```bash
# Verify nouveau is blacklisted
cat /etc/modprobe.d/blacklist-nvidia-nouveau.conf

# Rebuild initramfs
sudo update-initramfs -u

# Reboot
sudo reboot
```

### Permission Errors

If you encounter permission issues:
```bash
# Run verification as root
sudo ./pixinsight_gpu_setup.sh verify

# Check backup directory permissions
sudo ls -la /opt/pixinsight_gpu_backup/
```

## Restoring Original Configuration

If GPU acceleration doesn't work or causes issues:

### Quick Restore
```bash
sudo ./pixinsight_gpu_setup.sh restore
```

This will:
- Restore original PixInsight TensorFlow libraries
- Restore original startup script
- Keep CUDA/cuDNN installed (for future attempts)

### Verify Restore
```bash
ls -l /opt/PixInsight/bin/lib/libtensorflow*
```

Original libraries should be back in place.

## Complete Uninstallation

To remove all GPU acceleration components:

```bash
sudo ./pixinsight_gpu_setup.sh uninstall
```

You'll be prompted to:
- Remove CUDA 12.8 (optional - keep if used by other apps)
- Remove downloaded files
- Remove backup directory

## Updating PixInsight

⚠️ **Important**: When you update PixInsight, it will replace all files in `/opt/PixInsight/bin/lib/`, including the original TensorFlow libraries.

### After PixInsight Update:

**Option 1: Re-run the configure step**
```bash
sudo ./pixinsight_gpu_setup.sh
# Select option 1 (Install) - it will detect existing CUDA/TensorFlow
```

**Option 2: Manual fix**
```bash
# Move new CPU libraries aside
sudo mkdir -p /opt/PixInsight/bin/lib/original_tf_libs
sudo mv /opt/PixInsight/bin/lib/libtensorflow* /opt/PixInsight/bin/lib/original_tf_libs/

# Restart PixInsight
```

## Advanced Configuration

### Custom Installation Paths

Edit these variables in the script:
```bash
CUDA_VERSION="12.8.0"
TENSORFLOW_VERSION="2.15.0"
PIXINSIGHT_DIR="/opt/PixInsight"
BACKUP_DIR="/opt/pixinsight_gpu_backup"
```

### Using Different CUDA Versions

To use a different CUDA version, modify:
```bash
CUDA_VERSION="12.8.0"  # Change to your version
CUDA_SHORT="12-8"       # Change accordingly
CUDA_URL="..."          # Update URL
```

⚠️ Ensure TensorFlow version is compatible with your CUDA version!

## FAQ

**Q: Will this affect other applications using CUDA?**
A: No, this installs CUDA to a versioned directory (`cuda-12.8`) alongside any existing CUDA installations.

**Q: Can I use this with AMD GPUs?**  
A: No, this script is specifically for NVIDIA GPUs.

**Q: Do I need to reinstall after PixInsight updates?**  
A: Yes, PixInsight updates replace library files. Simply re-run the configuration step.

**Q: Can I keep both CPU and GPU versions?**  
A: Not simultaneously. Use the restore/install commands to switch between them.

**Q: Is this safe for my PixInsight installation?**  
A: Yes, all original files are backed up and can be restored at any time.

**Q: What if I have multiple GPUs?**  
A: CUDA will automatically use the first available GPU. To select a specific GPU, set `CUDA_VISIBLE_DEVICES` environment variable.

## Credits and References

Based on documentation and community contributions from:
- PixInsight Forum GPU acceleration guide
- RC Astro GPU acceleration documentation
- NVIDIA CUDA Toolkit documentation
- TensorFlow installation guides

## Support

- **PixInsight Forum**: [https://pixinsight.com/forum/](https://pixinsight.com/forum/)
- **RC Astro FAQ**: [https://www.rc-astro.com/frequently-asked-questions/](https://www.rc-astro.com/frequently-asked-questions/)
- **Script Issues**: Check installation log at `/opt/pixinsight_gpu_backup/install.log`

## License

This script is provided as-is for the PixInsight community. Use at your own risk.

## Version History

- **v1.0**: Initial release with full installation, restore, and uninstall functionality
