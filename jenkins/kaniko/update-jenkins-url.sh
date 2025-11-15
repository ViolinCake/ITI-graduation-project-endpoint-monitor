# set -e

# # $1 is now the absolute path to the tf_eks_modules directory, passed by Terraform.
# # This variable is now reliable.
# TF_DIR="$1" 

# # Get the directory where this script is located (only needed for index.yaml path)
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# KANIKO_YAML="${SCRIPT_DIR}/index.yaml"

# echo "🔍 Getting Jenkins ALB DNS from Terraform..."

# # Check if terraform directory exists (now using the reliable $TF_DIR)
# if [ ! -d "$TF_DIR" ]; then
#     echo "❌ Error: Terraform directory not found at $TF_DIR"
#     exit 1
# fi

# # Get Jenkins ALB DNS from Terraform output
# # We must cd into the directory containing the .terraform folder for 'terraform output' to work correctly.
# cd "$TF_DIR"
# JENKINS_DNS=$(terraform output -json 2>/dev/null | jq -r '.jenkins_alb_dns.value // empty')

# if [ -z "$JENKINS_DNS" ]; then


#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../tf_eks_modules"
KANIKO_YAML="${SCRIPT_DIR}/index.yaml"

echo "🔍 Getting Jenkins ALB DNS from Terraform..."

# Check if terraform directory exists
if [ ! -d "$TF_DIR" ]; then
    echo "❌ Error: Terraform directory not found at $TF_DIR"
    exit 1
fi

# Get Jenkins ALB DNS from Terraform output
cd "$TF_DIR"
JENKINS_DNS=$(terraform output -json 2>/dev/null | jq -r '.jenkins_alb_dns.value // empty')

if [ -z "$JENKINS_DNS" ]; then
# ... (rest of the script is correct)
    echo "❌ Error: Could not get jenkins_alb_dns from Terraform output"
    echo "Run 'terraform apply' first to create the infrastructure"
    exit 1
fi

JENKINS_URL="http://${JENKINS_DNS}"

echo "✅ Found Jenkins URL: $JENKINS_URL"
echo ""
echo "📝 Updating $KANIKO_YAML..."

# Update the YAML file using sed
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|value: 'http://.*'|value: '${JENKINS_URL}'|g" "$KANIKO_YAML"
else
    # Linux
    sed -i "s|value: 'http://.*'|value: '${JENKINS_URL}'|g" "$KANIKO_YAML"
fi

echo "✅ Updated JENKINS_URL to: $JENKINS_URL"
echo ""
echo "📋 Verify the change:"
grep -A 1 "JENKINS_URL" "$KANIKO_YAML"
echo ""

# Git auto-commit and push
echo "🔄 Committing changes to Git..."
cd "${SCRIPT_DIR}/.."

# Check if there are changes to commit
if git diff --quiet kaniko/index.yaml; then
    echo "ℹ️  No changes to commit (Jenkins URL unchanged)"
else
    echo "📝 Changes detected, committing..."
    
    # Configure git if needed (for CI/CD environments)
    if [ -z "$(git config user.email)" ]; then
        git config user.email "terraform-automation@github.com"
        git config user.name "Terraform Automation"
    fi
    
    # Stage the file
    git add kaniko/index.yaml
    
    # Commit with descriptive message
    COMMIT_MSG="chore: Update Jenkins URL to ${JENKINS_URL}

Auto-updated by Terraform after infrastructure changes.
Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    
    git commit -m "$COMMIT_MSG"
    
    # Push to GitHub
    echo "🚀 Pushing to GitHub..."
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    
    if git push origin "$CURRENT_BRANCH"; then
        echo "✅ Successfully pushed to GitHub (branch: $CURRENT_BRANCH)"
    else
        echo "⚠️  Warning: Failed to push to GitHub"
        echo "You may need to push manually or check your credentials"
        exit 0  # Don't fail the Terraform apply
    fi
fi

echo ""
echo "✅ Done! You can now use the updated kaniko/index.yaml in Jenkins"
