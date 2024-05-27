#!/bin/bash

# Container scanning is the process of analyzing components within containers to uncover
# potential security threats. It is integral to ensuring that the software remains secure
# as it progresses through the application life cycle. Container scanning takes its cues
# from practices like vulnerability scanning and penetration testing.

# This script uses Trivy, a simple and comprehensive vulnerability scanner for containers
# and other artifacts. Trivy can find vulnerabilities, IaC misconfigurations, secrets,
# SBOM discovery, Cloud scanning, Kubernetes security risks, and more.
# More information about Trivy can be found at https://trivy.dev/.

# This shell script automates the process of scanning container images and generate security reports.
# These reports are saved as Text files in a designated directory.

# Check if trivy is installed and install it if not
if ! command -v trivy &> /dev/null; then
    echo "Trivy is not installed. Installing..."
    wget https://github.com/aquasecurity/trivy/releases/download/v0.51.1/trivy_0.51.1_Linux-64bit.deb
    sudo dpkg -i trivy_0.51.1_Linux-64bit.deb
else
    echo "Found trivy, using trivy v$(trivy -v | cut -d ' ' -f 2)"
fi

# Get today's date in the desired format for folder naming
TODAY_DATE=$(date +'%d-%m-%Y')
CURRENT_TIME=$(date +'%H%M%S')

# Define the root and sub directory name
ROOT_DIR="image-scanner-reports"
DIR="bahmni-${TODAY_DATE}"

# Create the root and sub directory if it doesn't exist
mkdir -p "$ROOT_DIR/$DIR"

# Define the Output File
output_file_txt="$ROOT_DIR/${DIR}/${TODAY_DATE}_${CURRENT_TIME}.txt"

echo "Generating scan report...."

# Function to generate text table row for severity counts
function severity_count_row() {
  printf "%-40s %-10s %-10s %-10s %-10s %-10s\n" "$1" "$2" "$3" "$4" "$5" "$6"
}

# Start the text report
report_text="Trivy Scan Results\n"
report_text+="===================\n"
report_text+="$(printf "%-40s %-10s %-10s %-10s %-10s %-10s\n" "Image" "CRITICAL" "HIGH" "MEDIUM" "LOW" "UNKNOWN")"
report_text+="\n$(printf '%.0s-' {1..90})\n"

# Populate the images array
images=("bahmni/proxy"
        "bahmni/openmrs"
        "bahmni/openmrs-db:demo-latest"
        "bahmni/bahmni-web"
        "bahmni/default-config"
        "bahmni/reports"
        "bahmni/implementer-interface"
        "bahmni/appointments"
        "bahmni/patient-documents"
        "bahmni/sms-service"
        "bahmni/openelis-db:demo-latest"
        "bahmni/openelis"
        "bahmni/odoo-16-db:demo-latest"
        "bahmni/odoo-16"
        "bahmni/odoo-10-db:demo-latest"
        "bahmni/odoo-10"
        "bahmni/odoo-connect"
        "bahmni/dcm4chee"
        "bahmni/pacs-simulator"
        "bahmni/pacs-integration"
        "bahmni/bahmni-metabase"
        "bahmni/bahmni-mart"
        "bahmni/bahmni-lab"
        "bahmni/crater-php"
        "bahmni/crater-nginx"
        "bahmni/crater-atomfeed"
        "bahmni/clinic-config"
        "bahmni/atomfeed-console"
        "bahmni/event-router-service"
        "bahmni/microfrontend-ipd"
        "bahmni/cdss-reference"
        "bahmni/snomed-default-config"
        "bahmni/snomed-clinic-config")

echo "Scanning the below images:"

for image in "${images[@]}"; do
    echo "-> $image"
done

for image in "${images[@]}"; do
  echo "Scanning ------- $image"
  # Scan the image using Trivy and save JSON output to temporary file
  scan_results_file=$(mktemp)
  trivy image --severity HIGH,CRITICAL -f json "$image" > "$scan_results_file"
  # Check if there are vulnerabilities
  vulnerabilities=$(jq '.["Results"][0]["Vulnerabilities"] | length > 0' "$scan_results_file")

  if [[ "$vulnerabilities" != "true" ]]; then
    report_text+=$(severity_count_row "$image" "0" "0" "0" "0" "0")
    report_text+="\n"
    rm "$scan_results_file"
    continue
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
done

# Write the text report to a file
echo -e "$report_text" > "${output_file_txt}"

echo "Text report generated: ${output_file_txt}"