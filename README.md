# bahmni-infra-utils

Non-application specific utilities for Bahmni infra

## 📦 [image-scanner.sh](./image-scanner.sh)

This shell script automates the process of scanning images from a specific Docker organization (passed in, as an argument) using the Trivy vulnerability scanner. The script retrieves a list of Docker repositories from Docker Hub and runs Trivy scans on each image to generate security reports. These reports are saved as HTML files in a designated directory.

To use this script:

1. Save the script as image-scanner.sh.
2. Make the script executable by running the following command in your terminal:

    ``` bash
    chmod +x image-scanner.sh
    ```

3. Run the script with the organization name as the argument to generate the scan report of the images from bahmni namespace.

    Example usage:

    ``` bash
    ./image-scanner.sh bahmni
    ```

    **_NOTE:_** Replace `./image-scanner.sh` with the actual path to your script file if it's located in a different directory.

## 📦 [html.tpl](./html.tpl)

The provided HTML template is used by the Trivy vulnerability scanner in the `image-scanner.sh` script to generate detailed reports on the images. The template is responsible for formatting the vulnerability and misconfiguration data produced by Trivy scans into an easily readable and visually structured HTML document.

## 📦 [setArtifactVersion.sh](./setArtifactVersion.sh)

This script is used in GitHub Actions to set `ARTIFACT_VERSION` as an environment variable in the actions runner. It determines the version based on the context of the GitHub event (tag, release branch, or other branch) and supports two optional arguments:

- **version**: A custom version to be set.
- **appversionFile**: A custom file path to read the version from if no version is provided.

If either or both arguments are omitted, the script will default to using standard values.

The version is set as follows:

- **Tag Push**: If the push is a tag, the version is the tag name.
- **Release Branch Push**: If the push is on a branch named `release-<version>`, the version is `<version>-rc`.
- **Other Branch Push**:
  - The version will be `<version>-<github_run_number>`, where `<version>` is read from the specified version file or the default `package/.appversion` file if no file is provided.
  - If a version is provided as the first argument, it will be used directly instead of reading from a file.

### Usage

You can run the script with the following options:

- **Without arguments**:

  ```bash
  ./setArtifactVersion.sh
  ```

  This will use the default file `package/.appversion` to read the version if necessary.

- **With only the version argument**:

  ``` bash
  ./setArtifactVersion.sh <version>
  ```

  The script will use the provided version but still default to using `package/.appversion` for the file.

- **With only appversionFile**:

  ``` bash
  ./setArtifactVersion.sh "" path/to/custom/.appversion
  ```

    You can pass an empty string (`""`) for the version, followed by the custom appversionFile. The script will then read the version from the provided file and apply the standard logic.

- **With both version and custom appversionFile**:

  ``` bash
  ./setArtifactVersion.sh <version> path/to/custom/.appversion
  ```

  This allows specifying both a custom version and a custom file to read from.

## 📦 [transifex.sh](./transifex.sh)

This script simplifies the process of managing translations for Bahmni projects. It is used for pushing and pulling translations to/from Transifex. It checks if the Transifex CLI is installed, and if not, installs it. Then, it performs the specified Transifex operation (push or pull) based on the provided argument.

To use this script:

1. Save the script in your repository.
2. Make sure to have a `.tx/config` file in your repository for Transifex configuration.
3. Make the script executable by running the following command in your terminal:

    ``` bash
    chmod +x transifex.sh
    ```

4. Run the script with the appropriate argument (push or pull) to perform the desired operation.

    Example usage:

    ``` bash
    ./transifex.sh push
    ./transifex.sh pull
    ```

    **_NOTE:_** Replace `./transifex.sh` with the actual path to your script file if it's located in a different directory.

## 📦 [trivy_scan.sh](./trivy_scan.sh)

This script can be used in Github Actions to run a [Trivy Filesystem scan](https://aquasecurity.github.io/trivy/v0.19.2/vulnerability/scanning/filesystem/) and [Secrets Scan](https://aquasecurity.github.io/trivy/v0.27.1/docs/secret/scanning/).
Here are the instructions for how to use it:

- You can add the following step to your Github Actions workflow:

    ``` yml
    - name: Trivy Scan
      run: |
        wget -q https://raw.githubusercontent.com/Bahmni/bahmni-infra-utils/main/trivy_scan.sh && chmod +x trivy_scan.sh
        ./trivy_scan.sh
        rm trivy_scan.sh.sh
    ```

This will download the script from the Github repository, make it executable, run it, and then remove it. You can also pass command line arguments to the script in this workflow step to specify the paths to scan.

``` bash
./trivy_scan.sh <path> <path> 
```
