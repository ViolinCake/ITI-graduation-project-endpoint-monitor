#!/bin/bash
set -euo pipefail

# This script updates the Jenkins URL in the kaniko pod template and commits to Git
# Usage: ./update-jenkins-url.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KANIKO_FILE="$PROJECT_ROOT/jenkins/kaniko/index.yaml"

echo "🔄 Updating Jenkins URL in kaniko pod template..."

# Get Jenkins URL from Terraform output
cd "$SCRIPT_DIR/.."
JENKINS_URL=$(terraform output -raw jenkins_url 2>/dev/null || echo "")

if [ -z "$JENKINS_URL" ]; then
  echo "❌ Error: Could not retrieve Jenkins URL from Terraform output"
  echo "   Make sure you're in the terraform directory and have run 'terraform apply'"
  exit 1
fi

echo "✅ Jenkins URL: $JENKINS_URL"

# Check if the kaniko file exists
if [ ! -f "$KANIKO_FILE" ]; then
  echo "❌ Error: Kaniko pod template not found at $KANIKO_FILE"
  exit 1
fi

# Update the JENKINS_URL value in the file
# Using sed to replace the line with the JENKINS_URL environment variable
if grep -q "name: JENKINS_URL" "$KANIKO_FILE"; then
  # Create a backup
  cp "$KANIKO_FILE" "$KANIKO_FILE.bak"
  
  # Use sed to replace the value line that comes after "name: JENKINS_URL"
  sed -i "/name: JENKINS_URL/,/value:/ s|value:.*|value: '$JENKINS_URL'|" "$KANIKO_FILE"
  
  echo "✅ Updated Jenkins URL in $KANIKO_FILE"
  
  # Show the diff
  echo ""
  echo "📝 Changes made:"
  diff "$KANIKO_FILE.bak" "$KANIKO_FILE" || true
  rm "$KANIKO_FILE.bak"
else
  echo "⚠️  Warning: JENKINS_URL environment variable not found in $KANIKO_FILE"
  exit 1
fi

# Commit and push to GitHub
cd "$PROJECT_ROOT"

# Check if there are changes
if git diff --quiet "$KANIKO_FILE"; then
  echo "ℹ️  No changes to commit (Jenkins URL is already up to date)"
  exit 0
fi

echo ""
echo "📤 Committing and pushing changes to GitHub..."

# Configure git if needed (use existing config)
git add "$KANIKO_FILE"
git commit -m "chore: update Jenkins URL to $JENKINS_URL

Auto-updated by Terraform post-apply script"

# Push to the current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push origin "$CURRENT_BRANCH"

echo "✅ Successfully pushed Jenkins URL update to GitHub"
echo "   Branch: $CURRENT_BRANCH"
echo "   File: jenkins/kaniko/index.yaml"
