#!/bin/bash

# AIMBOT Recon Tool
# Author: Bug Hunter
# Version: 1.0

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo -e "${YELLOW}AIMBOT - Automated Reconnaissance Tool${NC}"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -d, --domain <domain>    Target domain to scan"
    echo "  -o, --output <dir>       Output directory (default: ./aimbot_recon)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -d example.com -o ./recon_results"
    exit 1
}

# Check if required tools are installed
check_dependencies() {
    local tools=("subfinder" "amass" "sublist3r" "httpx" "nuclei" "waybackurls" "gospider")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo -e "${RED}Error: $tool is not installed${NC}"
            exit 1
        fi
    done
}

# Subdomain Enumeration
enumerate_subdomains() {
    local domain="$1"
    local output_dir="$2"

    echo -e "${GREEN}[+] Starting Subdomain Enumeration${NC}"
    
    # Create subdomain directory
    mkdir -p "$output_dir/subdomains"

    # Run multiple subdomain tools
    subfinder -d "$domain" -o "$output_dir/subdomains/subfinder.txt"
    amass enum -d "$domain" -o "$output_dir/subdomains/amass.txt"
    sublist3r -d "$domain" -o "$output_dir/subdomains/sublist3r.txt"

    # Merge and sort unique subdomains
    cat "$output_dir/subdomains/subfinder.txt" \
        "$output_dir/subdomains/amass.txt" \
        "$output_dir/subdomains/sublist3r.txt" \
        | sort -u > "$output_dir/subdomains/all_subdomains.txt"

    echo -e "${GREEN}[✓] Subdomain Enumeration Complete${NC}"
}

# Find Live Subdomains
find_live_subdomains() {
    local output_dir="$1"
    
    echo -e "${GREEN}[+] Finding Live Subdomains${NC}"
    
    cat "$output_dir/subdomains/all_subdomains.txt" | httpx -silent > "$output_dir/subdomains/live_subdomains.txt"
    
    echo -e "${GREEN}[✓] Live Subdomain Discovery Complete${NC}"
}

# Discover JS Files and Endpoints
discover_js_endpoints() {
    local domain="$1"
    local output_dir="$2"

    echo -e "${GREEN}[+] Discovering JS Files and Endpoints${NC}"
    
    # Create JS and endpoint directories
    mkdir -p "$output_dir/js_files" "$output_dir/endpoints"

    # Find JS files
    gospider -s "$domain" -o "$output_dir/js_files"
    
    # Extract wayback URLs
    waybackurls "$domain" > "$output_dir/endpoints/wayback_urls.txt"
    
    # Extract JS file paths
    grep '\.js$' "$output_dir/endpoints/wayback_urls.txt" > "$output_dir/js_files/js_urls.txt"
    
    echo -e "${GREEN}[✓] JS and Endpoint Discovery Complete${NC}"
}

# Run Vulnerability Scans
run_vulnerability_scans() {
    local output_dir="$1"

    echo -e "${GREEN}[+] Running Vulnerability Scans${NC}"
    
    # Create vulnerability directory
    mkdir -p "$output_dir/vulnerabilities"

    # XSS Scan
    nuclei -l "$output_dir/subdomains/live_subdomains.txt" -t nuclei-templates/vulnerabilities/generic-xss.yaml > "$output_dir/vulnerabilities/xss_results.txt"

    # SQL Injection Scan
    nuclei -l "$output_dir/subdomains/live_subdomains.txt" -t nuclei-templates/vulnerabilities/sqli.yaml > "$output_dir/vulnerabilities/sql_results.txt"

    # Known Vulnerabilities Scan
    nuclei -l "$output_dir/subdomains/live_subdomains.txt" -t nuclei-templates/vulnerabilities/ > "$output_dir/vulnerabilities/known_vulnerabilities.txt"

    echo -e "${GREEN}[✓] Vulnerability Scanning Complete${NC}"
}

# Main Function
main() {
    # Parse command-line arguments
    ARGS=$(getopt -o d:o:h --long domain:,output:,help -n "$0" -- "$@")
    
    if [ $? -ne 0 ]; then
        usage
    fi

    eval set -- "$ARGS"

    local domain=""
    local output_dir="./aimbot_recon"

    while true; do
        case "$1" in
            -d|--domain)
                domain="$2"
                shift 2
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "Internal error!"
                exit 1
                ;;
        esac
    done

    # Validate domain
    if [ -z "$domain" ]; then
        echo -e "${RED}Error: Domain is required${NC}"
        usage
    fi

    # Header
    echo -e "${YELLOW}========== AIMBOT RECONNAISSANCE TOOL ==========${NC}"
    echo -e "${GREEN}Target Domain: $domain${NC}"
    echo -e "${GREEN}Output Directory: $output_dir${NC}"

    # Check dependencies
    check_dependencies

    # Create output directory
    mkdir -p "$output_dir"

    # Run Reconnaissance Stages
    enumerate_subdomains "$domain" "$output_dir"
    find_live_subdomains "$output_dir"
    discover_js_endpoints "$domain" "$output_dir"
    run_vulnerability_scans "$output_dir"

    echo -e "${YELLOW}========== RECON COMPLETE ==========${NC}"
}

# Run the main function with all arguments
main "$@"
