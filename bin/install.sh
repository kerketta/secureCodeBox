#!/usr/bin/env bash

# Official installation script for the secureCodeBox
#
# Creates namespace, securecodebox-system, and installs the operator.
# Then installs all possible resources (scanners, demo-apps, hooks).
#
# There exist two modes:
# Call without parameters to install interactively
# Call with --all to install all available resources automatically
# Call with --scanners / --demo-apps / --hooks to only install the wanted resources
# Call with --help for usage information
#
# For more information see https://docs.securecodebox.io/

set -eu
shopt -s extglob

COLOR_HIGHLIGHT="\e[35m"
COLOR_OK="\e[32m"
COLOR_ERROR="\e[31m"
COLOR_RESET="\e[0m"

# @see: http://wiki.bash-hackers.org/syntax/shellvars
[ -z "${SCRIPT_DIRECTORY:-}" ] \
  && SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

BASE_DIR=$(dirname "${SCRIPT_DIRECTORY}")

function print() {
  if [[ $# == 0 ]]; then
    echo
  elif [[ $# == 1 ]]; then
    local message="${1}"
    echo "${message}"
  elif [[ $# == 2 ]]; then
    local color="${1}"
    local message="${2}"
    echo -e "${color}${message}${COLOR_RESET}"
  fi
}

function usage() {
  local usage
  usage="Usage: $(basename "$0") [--all] [--scanners] [--hooks] [--demo-apps] [--help]"
  local help
  help=$(cat <<- EOT
        The installation is interactive if no arguments are provided.

        Options:
          --all          Install scanners, demo-apps and hooks
          --scanners     Install scanners
          --demo-apps    Install demo-apps
          --hooks        Install hooks
          -h|--help      Show help

        Examples:
        install.sh --all
        Installs the operator in namespace: securecodebox-system and
        all resources in namespace: default

        install.sh --hooks --scanners
        Installs only operator, scanners and hooks
EOT
  )
  print "SecureCodeBox Install Script"
  print "$usage"
  print
  print "$help"
}

function checkKubectl() {
  print
  print "Checking kubectl..."
  local kube
  kube=$(kubectl cluster-info) || true

  if [[ $kube == *"running"* ]]; then
    print "$COLOR_OK" "Kubectl is there!"
  else
    print "$COLOR_ERROR" "Kubectl not found or not working, quitting..."
    exit 1
  fi
}

function checkHelm() {
  print
  print "Checking helm..."
  local helm
  helm=$(helm version) || true

  if [[ $helm == *"Version"* ]]; then
    print "$COLOR_OK" "Helm is there!"
  else
    print "$COLOR_ERROR" "Helm not found or not working, quitting..."
    exit 1
  fi
}

function createNamespaceAndInstallOperator() {
  print
  print "Creating namespace securecodebox-system"
  kubectl create namespace securecodebox-system || print "Namespace already exists..."

  print "Installing the operator in the securecodebox-system namespace"

  if [[ $(helm -n securecodebox-system upgrade --install securecodebox-operator "$BASE_DIR"/operator/) ]]; then
    print "$COLOR_OK" "Successfully installed the operator!"
  else
    print "$COLOR_ERROR" "Operator installation failed, cancelling..." && exit 1
  fi
}

function installResources() {
  local resource_directory="$1"
  local namespace="$2"
  local unattended="$3"

  local resources=()
  for path in "$resource_directory"/*; do
    [ -d "${path}" ] || continue # skip if not a directory
    local directory
    directory="$(basename "${path}")"
    resources+=("${directory}")
  done

  if [[ $unattended == True ]]; then
    for resource in "${resources[@]}"; do
      local resource_name="${resource//+([_])/-}" # Necessary because ssh_scan is called ssh-scan
      helm upgrade --install -n "$namespace" "$resource_name" "$resource_directory"/"$resource"/ \
      || print "$COLOR_ERROR" "Installation of '$resource' failed"
    done

  else
    for resource in "${resources[@]}"; do
      print "Do you want to install $resource? [y/N]"
      local line
      read -r line

      if [[ $line == *[Yy] ]]; then
        local resource_name="${resource//+([_])/-}"
        helm upgrade --install -n "$namespace" "$resource_name" "$resource_directory"/"$resource"/ \
        || print "$COLOR_ERROR" "Installation of '$resource' failed"
      fi
    done
  fi

  print
  print "$COLOR_OK" "Completed to install '$resource_directory'!"
}

function interactiveInstall() {
  print "$COLOR_HIGHLIGHT" "Welcome to the secureCodeBox!"
  print "This interactive installation script will guide you through all the relevant installation steps in order to have you ready to scan."
  print "Start? [y/N]"

  read -r LINE

  if [[ $LINE == *[Yy] ]]; then
    print "Starting!"
  else
    exit
  fi

  checkKubectl
  checkHelm
  createNamespaceAndInstallOperator

  print
  print "Starting to install scanners..."
  installResources "$BASE_DIR/scanners" "default" False

  print
  print "Starting to install demo-apps..."
  print "Do you want to install the demo apps in a separate namespace? Otherwise they will be installed into the [default] namespace [y/N]"
  read -r line
  NAMESPACE="default"
  if [[ $line == *[Yy] ]]; then
    print "Please provide a name for the namespace:"
    read -r NAMESPACE
    kubectl create namespace "$NAMESPACE" || print "Namespace already exists or could not be created.. "
  fi

  installResources "$BASE_DIR/demo-apps" "$NAMESPACE" False

  print
  print "Starting to install hooks..."
  installResources "$BASE_DIR/hooks" "default" False

  print
  print "$COLOR_OK" "Information about your cluster:"
  kubectl get namespaces
  print
  kubectl get scantypes
  print
  kubectl get pods

  print
  print "$COLOR_OK" "Finished installation successfully!"
}

function unattendedInstall() {
  checkKubectl
  checkHelm
  createNamespaceAndInstallOperator

  local install_scanners=$1
  local install_demo_apps=$2
  local install_hooks=$3

  if [[ $install_scanners == true ]]; then
    print "Starting to install scanners..."
    installResources "$BASE_DIR/scanners" "default" True
  fi

  if [[ $install_demo_apps == true ]]; then
    print "Starting to install demo-apps..."
    installResources "$BASE_DIR/demo-apps" "default" True
  fi

  if [[ $install_hooks == true ]]; then
    print "Starting to install hooks..."
    installResources "$BASE_DIR/hooks" "default" True
  fi

  print "$COLOR_OK" "Finished installation successfully!"
}

function parseArguments() {
  local install_scanners=false
  local install_demo_apps=false
  local install_hooks=false

  while (( "$#" )); do
        case "$1" in
          --scanners)
            install_scanners=true
            shift # Pop current argument from array
            ;;
          --demo-apps)
            install_demo_apps=true
            shift
            ;;
          --hooks)
            install_hooks=true
            shift
            ;;
          --all)
            install_scanners=true
            install_demo_apps=true
            install_hooks=true
            shift
            ;;
          -h|--help)
            usage
            exit
            ;;
          --*) # unsupported flags
            echo "Error: Unsupported flag $1" >&2
            usage
            exit 1
            ;;
          *) # preserve positional arguments
            shift
            ;;
        esac
  done

  unattendedInstall $install_scanners $install_demo_apps $install_hooks
}

print "$COLOR_HIGHLIGHT" "                                                                             "
print "$COLOR_HIGHLIGHT" "                               _____           _      ____                   "
print "$COLOR_HIGHLIGHT" "                              / ____|         | |    |  _ \                  "
print "$COLOR_HIGHLIGHT" "  ___  ___  ___ _   _ _ __ ___| |     ___   __| | ___| |_) | _____  __       "
print "$COLOR_HIGHLIGHT" " / __|/ _ \/ __| | | | '__/ _ \ |    / _ \ / _  |/ _ \  _ < / _ \ \/ /       "
print "$COLOR_HIGHLIGHT" " \__ \  __/ (__| |_| | | |  __/ |___| (_) | (_| |  __/ |_) | (_) >  <        "
print "$COLOR_HIGHLIGHT" " |___/\___|\___|\__,_|_|  \___|\_____\___/ \__,_|\___|____/ \___/_/\_\       "
print "$COLOR_HIGHLIGHT" "                                                                             "

if [[ $# == 0 ]]; then
    interactiveInstall
  else
    parseArguments "$@"
fi
