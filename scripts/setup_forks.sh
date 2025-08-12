#!/bin/bash
# Script to help set up forked repositories for TrueNAS Dragonfish maintenance

set -e

echo "=========================================="
echo "TrueNAS Dragonfish Fork Setup Assistant"
echo "=========================================="
echo ""

# Configuration
GITHUB_USER="secretzer0"
WORK_DIR="$HOME/dragonfish-forks"

# Create working directory
echo "Creating working directory: $WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Function to setup a fork
setup_fork() {
    local REPO_NAME=$1
    local ORIGINAL_OWNER=$2
    local CUSTOM_CHANGES=$3
    
    echo ""
    echo "Setting up $REPO_NAME..."
    echo "----------------------------------------"
    
    if [ -d "$REPO_NAME" ]; then
        echo "Directory $REPO_NAME already exists, skipping clone..."
        cd "$REPO_NAME"
        git fetch --all
    else
        echo "Please fork https://github.com/$ORIGINAL_OWNER/$REPO_NAME on GitHub first!"
        echo "Press Enter when done..."
        read
        
        echo "Cloning $GITHUB_USER/$REPO_NAME..."
        git clone "git@github.com:$GITHUB_USER/$REPO_NAME.git"
        cd "$REPO_NAME"
        
        # Add upstream remote
        git remote add upstream "https://github.com/$ORIGINAL_OWNER/$REPO_NAME.git"
        git fetch upstream
    fi
    
    # Check if main branch exists
    if ! git show-ref --verify --quiet refs/heads/main; then
        echo "Creating main branch from master..."
        git checkout -b main
        
        # Apply custom changes
        if [ "$CUSTOM_CHANGES" == "update_branch_refs" ]; then
            echo "Updating branch references from master to main..."
            find . -type f -name "*.py" -exec sed -i.bak 's/master/main/g' {} \;
            find . -type f -name "*.yaml" -exec sed -i.bak 's/master/main/g' {} \;
            find . -type f -name "*.yml" -exec sed -i.bak 's/master/main/g' {} \;
            find . -type f -name "*.md" -exec sed -i.bak 's/\[master\]/[main]/g' {} \;
            find . -name "*.bak" -delete
            
            # Commit changes if any
            if ! git diff --quiet; then
                git add -A
                git commit -m "Update default branch references from master to main

This change ensures compatibility with our Dragonfish maintenance repository
which uses 'main' as the default branch for inclusivity."
            fi
        fi
        
        git push -u origin main
        echo "NOTE: Set 'main' as default branch in GitHub settings!"
    else
        echo "Main branch already exists"
        git checkout main
        git pull origin main
    fi
    
    cd "$WORK_DIR"
}

# Function to create Dragonfish-specific modifications
apply_dragonfish_mods() {
    local REPO_NAME=$1
    
    echo "Applying Dragonfish-specific modifications to $REPO_NAME..."
    cd "$WORK_DIR/$REPO_NAME"
    
    # Create a Dragonfish maintenance notice
    cat > DRAGONFISH_MAINTENANCE.md << 'EOF'
# TrueNAS Dragonfish Maintenance Fork

This is a maintenance fork specifically for TrueNAS Dragonfish (24.04) users.

## Purpose
- Maintain compatibility with TrueNAS Dragonfish 24.04
- Provide stability for users who cannot upgrade to Electric Eel
- Apply security patches and critical bug fixes

## Differences from Upstream
- Default branch is 'main' instead of 'master'
- Configured for the Dragonfish charts repository structure
- Conservative update policy for stability

## Upstream
Original repository: https://github.com/truenas/$REPO_NAME

## Maintenance
Maintained by: secretzer0 <tmelhiser@gmail.com>
For: https://github.com/secretzer0/ix-charts
EOF
    
    git add DRAGONFISH_MAINTENANCE.md
    git commit -m "Add Dragonfish maintenance documentation" || echo "Already documented"
    git push origin main
}

# Main execution
echo "This script will help you set up the forked repositories."
echo "Make sure you have forked the following on GitHub first:"
echo "  1. https://github.com/truenas/catalog_validation"
echo "  2. https://github.com/truenas/catalog_update"
echo ""
echo "Press Enter to continue..."
read

# Setup catalog_validation fork
setup_fork "catalog_validation" "truenas" "update_branch_refs"
apply_dragonfish_mods "catalog_validation"

# Setup catalog_update fork
setup_fork "catalog_update" "truenas" "update_branch_refs"
apply_dragonfish_mods "catalog_update"

echo ""
echo "=========================================="
echo "Fork Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Go to GitHub settings for each repository and set 'main' as default branch"
echo "2. Update ix-charts/docker/Dockerfile to use the forked repositories"
echo "3. Build and test the new Docker image"
echo "4. Update GitHub Actions workflows to use the new image"
echo ""
echo "Repositories are located in: $WORK_DIR"
echo ""
echo "To build the Docker image with forks:"
echo "  cd $HOME/Desktop/ix-charts/docker"
echo "  cp Dockerfile.forked Dockerfile"
echo "  ./build.sh"