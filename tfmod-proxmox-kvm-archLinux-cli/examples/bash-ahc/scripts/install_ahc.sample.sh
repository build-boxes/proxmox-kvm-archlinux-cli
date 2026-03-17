#!/usr/bin/env bash

## INSTRUCTIONS: Make a copy of this file named "install_ahc.actual.sh" and fill in the Actual values.
##
# This is a Shadow file, illustrating what the actual file should contain.
# 

set -euo pipefail

# Example sustome_script.sh
# Installs: Accurate Hijri Calculator (AHC) in a Python virtual environment. https://github.com/accuhijri/ahc

# ------------------------------------------------------------
# Accurate Hijri Calculator (AHC) Automated Installer
# ------------------------------------------------------------

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${GREEN}=== Accurate Hijri Calculator (AHC) Installer ===${RESET}"

# ------------------------------------------------------------
# 1. Check for required system packages
# ------------------------------------------------------------
echo -e "${YELLOW}Installing system dependencies...${RESET}"

if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv git
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y python3 python3-pip python3-virtualenv git
elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y python3 python3-pip python3-virtualenv git
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Syu --noconfirm python python-pip python-virtualenv git    
else
    echo -e "${RED}Unsupported Linux distribution. Install Python3, pip, venv, and git manually.${RESET}"
    exit 1
fi

# ------------------------------------------------------------
# 2. Clone AHC repository
# ------------------------------------------------------------
echo -e "${YELLOW}Cloning AHC repository...${RESET}"

if [ ! -d "ahc" ]; then
    git clone https://github.com/hammadrauf/ahc.git
else
    echo -e "${YELLOW}Directory 'ahc' already exists. Updating...${RESET}"
    cd ahc
    git pull
    cd ..
fi

cd ahc

# ------------------------------------------------------------
# 3. Create virtual environment
# ------------------------------------------------------------
echo -e "${YELLOW}Creating Python virtual environment...${RESET}"

python3 -m venv venv
source venv/bin/activate

# ------------------------------------------------------------
# 4. Install Python dependencies
# ------------------------------------------------------------
echo -e "${YELLOW}Installing Python dependencies...${RESET}"

pip install --upgrade pip
pip install -r requirements.txt

# ------------------------------------------------------------
# 5. Install AHC package
# ------------------------------------------------------------
echo -e "${YELLOW}Installing AHC package...${RESET}"

pip install .

# ------------------------------------------------------------
# 6. Optional: Install geopandas (needed for visibility maps)
# ------------------------------------------------------------
echo -e "${YELLOW}Installing, optional package,  geopandas (needed for visibility maps)...${RESET}"
pip install geopandas

# ------------------------------------------------------------
# 7. Done
# ------------------------------------------------------------
echo -e "${GREEN}AHC installation complete!${RESET}"
echo -e "To activate the environment later, run:"
echo -e "${YELLOW}source ahc/venv/bin/activate${RESET}"
