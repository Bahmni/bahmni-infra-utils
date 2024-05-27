#!/bin/bash

# Container scanning is the process of analyzing components within containers to uncover 
# potential security threats. It is integral to ensuring that the software remains secure 
# as it progresses through the application life cycle. Container scanning takes its cues 
# from practices like vulnerability scanning and penetration testing.

# This script uses Trivy, a simple and comprehensive vulnerability scanner for containers
# and other artifacts. Trivy can find vulnerabilities, IaC misconfigurations, secrets, 
# SBOM discovery, Cloud scanning, Kubernetes security risks, and more. 
# More information about Trivy can be found at https://trivy.dev/.

# This shell script automates the process of scanning container images from a specific Docker 
# organization (passed in, as an argument) using the Trivy vulnerability scanner. The script 
# retrieves a list of Docker repositories from Docker Hub and runs Trivy scans on each image 
# to generate security reports. These reports are saved as HTML files in a designated directory.

# Function to generate text table row for severity counts
function severity_count_row() {
  printf "%-40s %-10s %-10s %-10s %-10s %-10s\n" "$1" "$2" "$3" "$4" "$5" "$6"
}

function get_vulnerabilities_count() {
    image=$1
    report_text=""
    scan_results_file=$(mktemp)
    trivy image --scanners vuln -f json "$image" > "$scan_results_file"
    if [ $? -ne 0 ]; then
        report_text+=$(severity_count_row "$image (Failed)" "-" "-" "-" "-" "-")
        report_text+="\n"
        echo "$report_text"
        return 1
    fi
    # Check if there are vulnerabilities
    vulnerabilities=$(jq '.["Results"][0]["Vulnerabilities"] | length > 0' "$scan_results_file")

    if [[ "$vulnerabilities" != "true" ]]; then
        report_text+=$(severity_count_row "$image" "0" "0" "0" "0" "0")
        report_text+="\n"
        echo "$report_text"
        return 0
    fi

    declare -A severity_count
    severity_count=(
        ["CRITICAL"]=0
        ["HIGH"]=0
        ["MEDIUM"]=0
        ["LOW"]=0
        ["UNKNOWN"]=0
    )

    results_length=$(jq '.["Results"] | length' "$scan_results_file")
    for ((i = 0; i < results_length; i++)); do
        # Check if there are vulnerabilities for the current result
        has_vulnerabilities=$(jq ".Results[$i] | has(\"Vulnerabilities\")" "$scan_results_file")
        if [[ "$has_vulnerabilities" != "true" ]]; then
        continue
        fi

        # Extract vulnerabilities for the current result
        vulnerabilities=$(jq -c ".Results[$i].Vulnerabilities[]" "$scan_results_file")

        # Loop over each vulnerability extracted from the JSON file
        while IFS=$'\n' read -r vulnerability; do
            severity=$(jq -r '.Severity' <<< "$vulnerability")
            # Update severity count
            if [[ -n "$severity" ]]; then
            ((severity_count["$severity"]++))
            fi
        done <<< "$vulnerabilities"
    done

    for severity in "CRITICAL" "HIGH" "MEDIUM" "LOW" "UNKNOWN"; do
        count="${severity_count["$severity"]}"
        if [[ ! $count -gt 0 ]]; then
        severity_count["$severity"]=0
        fi
    done
    # Add severity count row for the current image

    report_text+=$(severity_count_row "$image" "${severity_count["CRITICAL"]}" "${severity_count["HIGH"]}" "${severity_count["MEDIUM"]}" "${severity_count["LOW"]}" "${severity_count["UNKNOWN"]}")
    report_text+="\n"

    # Clean up the temporary file
    rm "$scan_results_file"

    echo "$report_text"

}
# Check if the organization name is provided as an argument
if [ -z "$1" ]; then
    echo "Error: Please provide the Docker organization name as an argument."
    echo "Usage: $0 <organization_name>"
    exit 1
fi

# Get Docker Organization Name from the script argument
ORG="$1"

# Check if trivy is installed and install it if not
if ! command -v trivy &> /dev/null; then
    echo "Trivy is not installed. Installing..."
    wget https://github.com/aquasecurity/trivy/releases/download/v0.51.1/trivy_0.51.1_Linux-64bit.deb
    sudo dpkg -i trivy_0.51.1_Linux-64bit.deb
else
    echo "Found trivy, using trivy v$(trivy -v | cut -d ' ' -f 2)"
fi

# Start the text report
summary_file_output="Trivy Scan Results Summary\n"
summary_file_output+="===================\n"
summary_file_output+="$(printf "%-40s %-10s %-10s %-10s %-10s %-10s\n" "Image" "CRITICAL" "HIGH" "MEDIUM" "LOW" "UNKNOWN")"
summary_file_output+="\n$(printf '%.0s-' {1..90})\n"

echo "Retrieving repository list ..."
REPO_LIST=$(curl -s "https://hub.docker.com/v2/repositories/${ORG}/?page_size=100" | jq -r '.results|.[]|.name')

# Get today's date in the desired format for folder naming
TODAY_DATE=$(date +'%d-%m-%Y')
CURRENT_TIME=$(date +'%H-%M-%S')
# Define the root and sub directory name
ROOT_DIR="image-scanner-reports"
DIR="bahmni-${TODAY_DATE}_${CURRENT_TIME}"

# Create the root and sub directory if it doesn't exist
mkdir -p "$ROOT_DIR/$DIR"
mkdir -p "$ROOT_DIR/summary"

echo "Generating scan report...."

# Iterate through each image and run Trivy scan
for image in $REPO_LIST; do
    # Replace '/' with '-' in the image name
    image_name=$(echo "$image" | tr '/' '-')

    # Define the Output File
    output_file_txt="$ROOT_DIR/${DIR}/${image}.html"

    # Run Trivy scan on the image
    echo "Scanning image: $image"
    trivy image --severity HIGH,CRITICAL --format template --template "@html.tpl" --output "$output_file_txt" "${ORG}/$image_name"
    echo "" >> "$output_file_txt"

    summary_file_output+="$(get_vulnerabilities_count "${ORG}/$image_name")"

    # Check if Trivy scan was successful
    if [ $? -eq 0 ]; then
        echo "Trivy scan completed for $image."
    else
        echo "Error: Trivy scan failed for $image."
    fi
done
echo -e "$summary_file_output" > "$ROOT_DIR/summary/${TODAY_DATE}_${CURRENT_TIME}.txt"
