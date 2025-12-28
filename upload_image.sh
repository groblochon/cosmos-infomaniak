#!/bin/bash

################################################################################
# Upload Custom Image to Infomaniak OpenStack
# 
# This script uploads custom images to Infomaniak OpenStack cloud platform.
# It handles authentication, image preparation, and upload operations.
#
# Usage: ./upload_image.sh <image_path> [options]
#
# Dependencies:
#   - openstack CLI
#   - curl (for API calls)
#   - file (for MIME type detection)
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration defaults
INFOMANIAK_API_ENDPOINT="${INFOMANIAK_API_ENDPOINT:-https://api.openstack.infomaniak.com}"
IMAGE_VISIBILITY="${IMAGE_VISIBILITY:-private}"
IMAGE_MIN_DISK="${IMAGE_MIN_DISK:-5}"
IMAGE_MIN_RAM="${IMAGE_MIN_RAM:-512}"
TIMEOUT="${TIMEOUT:-3600}"

################################################################################
# Helper Functions
################################################################################

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Display usage information
usage() {
    cat << EOF
Usage: $0 <image_path> [OPTIONS]

REQUIRED:
  <image_path>              Path to the image file to upload

OPTIONS:
  -n, --name NAME           Image name (default: filename)
  -d, --description DESC    Image description
  -f, --format FORMAT       Image format (qcow2, raw, iso, vmdk, vdi)
  -t, --disk-format FORMAT  Disk format (default: qcow2)
  -v, --visibility VIS      Visibility: private or public (default: private)
  --min-disk SIZE           Minimum disk size in GB (default: 5)
  --min-ram SIZE            Minimum RAM in MB (default: 512)
  --protected               Mark image as protected
  --timeout SECONDS         Upload timeout in seconds (default: 3600)
  -h, --help                Display this help message

ENVIRONMENT VARIABLES:
  OS_USERNAME               OpenStack username
  OS_PASSWORD               OpenStack password
  OS_PROJECT_NAME           OpenStack project name
  OS_AUTH_URL               OpenStack auth URL
  OS_REGION_NAME            OpenStack region name
  OS_INTERFACE              OpenStack interface (public/internal/admin)

EXAMPLES:
  # Upload with default settings
  ./upload_image.sh image.qcow2

  # Upload with custom name and description
  ./upload_image.sh image.qcow2 -n "My Custom Image" -d "Ubuntu 22.04 LTS"

  # Upload as public image with disk format
  ./upload_image.sh image.iso -f iso -v public

EOF
    exit 1
}

# Validate required tools are installed
check_dependencies() {
    local deps=("openstack" "curl" "file")
    local missing=0

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "Required command not found: $cmd"
            missing=$((missing + 1))
        fi
    done

    if [ $missing -gt 0 ]; then
        print_error "Please install missing dependencies"
        exit 1
    fi
}

# Validate OpenStack credentials
check_credentials() {
    local required_vars=("OS_USERNAME" "OS_PASSWORD" "OS_PROJECT_NAME" "OS_AUTH_URL")
    local missing=0

    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            print_error "Missing required environment variable: $var"
            missing=$((missing + 1))
        fi
    done

    if [ $missing -gt 0 ]; then
        print_error "Please set all required OpenStack environment variables"
        exit 1
    fi
}

# Validate image file
validate_image_file() {
    local image_path="$1"

    if [ ! -f "$image_path" ]; then
        print_error "Image file not found: $image_path"
        exit 1
    fi

    local file_size=$(stat -f%z "$image_path" 2>/dev/null || stat -c%s "$image_path" 2>/dev/null)
    if [ "$file_size" -lt 1048576 ]; then
        print_warning "Image file is very small ($(( file_size / 1024 ))KB)"
    fi

    print_info "Image file: $image_path ($(( file_size / 1048576 ))MB)"
}

# Get MIME type from file
get_mime_type() {
    local file_path="$1"
    file -b --mime-type "$file_path" 2>/dev/null || echo "application/octet-stream"
}

# Detect disk format from file extension
detect_disk_format() {
    local file_path="$1"
    local extension="${file_path##*.}"
    
    case "${extension,,}" in
        qcow2) echo "qcow2" ;;
        img|raw) echo "raw" ;;
        iso) echo "iso" ;;
        vmdk) echo "vmdk" ;;
        vdi) echo "vdi" ;;
        vpc) echo "vpc" ;;
        vhd) echo "vhd" ;;
        *) echo "qcow2" ;; # default
    esac
}

# Test OpenStack connection
test_openstack_connection() {
    print_info "Testing OpenStack connection..."
    
    if ! openstack image list &> /dev/null; then
        print_error "Failed to connect to OpenStack. Check credentials and configuration."
        exit 1
    fi
    
    print_success "OpenStack connection successful"
}

# Upload image to OpenStack
upload_image() {
    local image_path="$1"
    local image_name="$2"
    local disk_format="$3"
    local image_visibility="$4"
    local min_disk="$5"
    local min_ram="$6"
    local protected="$7"
    local description="$8"

    print_info "Preparing to upload image: $image_name"
    
    # Build openstack command
    local cmd="openstack image create"
    cmd="$cmd --file '$image_path'"
    cmd="$cmd --disk-format $disk_format"
    cmd="$cmd --container-format bare"
    cmd="$cmd --visibility $image_visibility"
    cmd="$cmd --min-disk $min_disk"
    cmd="$cmd --min-ram $min_ram"
    
    if [ -n "$description" ]; then
        cmd="$cmd --description '$description'"
    fi
    
    if [ "$protected" = true ]; then
        cmd="$cmd --protected"
    fi
    
    cmd="$cmd '$image_name'"
    
    print_info "Starting image upload (timeout: ${TIMEOUT}s)..."
    
    # Execute upload with timeout
    if timeout "$TIMEOUT" bash -c "eval $cmd"; then
        print_success "Image uploaded successfully: $image_name"
        
        # Display image information
        print_info "Retrieving image details..."
        openstack image show "$image_name"
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            print_error "Upload timeout after ${TIMEOUT} seconds"
        else
            print_error "Image upload failed with exit code: $exit_code"
        fi
        exit 1
    fi
}

# Verify image upload
verify_image_upload() {
    local image_name="$1"
    
    print_info "Verifying image upload..."
    
    local image_status=$(openstack image show "$image_name" -f value -c status 2>/dev/null || echo "")
    
    if [ -z "$image_status" ]; then
        print_error "Could not find uploaded image: $image_name"
        return 1
    fi
    
    case "$image_status" in
        active)
            print_success "Image is active and ready to use"
            return 0
            ;;
        queued|saving)
            print_warning "Image is still being processed (status: $image_status)"
            return 0
            ;;
        error)
            print_error "Image upload failed (status: error)"
            openstack image show "$image_name"
            return 1
            ;;
        *)
            print_warning "Image status: $image_status"
            return 0
            ;;
    esac
}

################################################################################
# Main Script
################################################################################

main() {
    local image_path=""
    local image_name=""
    local disk_format=""
    local description=""
    local protected=false

    # Parse command line arguments
    if [ $# -lt 1 ]; then
        usage
    fi

    image_path="$1"
    shift || true

    # Parse optional arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -n|--name)
                image_name="$2"
                shift 2
                ;;
            -d|--description)
                description="$2"
                shift 2
                ;;
            -f|--format)
                disk_format="$2"
                shift 2
                ;;
            -t|--disk-format)
                disk_format="$2"
                shift 2
                ;;
            -v|--visibility)
                IMAGE_VISIBILITY="$2"
                shift 2
                ;;
            --min-disk)
                IMAGE_MIN_DISK="$2"
                shift 2
                ;;
            --min-ram)
                IMAGE_MIN_RAM="$2"
                shift 2
                ;;
            --protected)
                protected=true
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Set image name from filename if not provided
    if [ -z "$image_name" ]; then
        image_name=$(basename "$image_path" | sed 's/\.[^.]*$//')
    fi

    # Auto-detect disk format if not provided
    if [ -z "$disk_format" ]; then
        disk_format=$(detect_disk_format "$image_path")
        print_info "Detected disk format: $disk_format"
    fi

    print_info "=========================================="
    print_info "Upload Image to Infomaniak OpenStack"
    print_info "=========================================="
    
    # Perform checks
    check_dependencies
    check_credentials
    validate_image_file "$image_path"
    test_openstack_connection
    
    print_info "Image Name: $image_name"
    print_info "Disk Format: $disk_format"
    print_info "Visibility: $IMAGE_VISIBILITY"
    print_info "Min Disk: ${IMAGE_MIN_DISK}GB"
    print_info "Min RAM: ${IMAGE_MIN_RAM}MB"
    [ "$protected" = true ] && print_info "Protected: Yes"
    print_info "=========================================="
    
    # Perform upload
    upload_image "$image_path" "$image_name" "$disk_format" "$IMAGE_VISIBILITY" \
                 "$IMAGE_MIN_DISK" "$IMAGE_MIN_RAM" "$protected" "$description"
    
    # Verify upload
    verify_image_upload "$image_name"
    
    print_info "=========================================="
    print_success "Upload process completed successfully!"
    print_info "=========================================="
}

# Run main function
main "$@"
