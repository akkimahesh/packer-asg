#!/bin/bash
set -e

# ==================== CONFIGURATION ====================
LAUNCH_TEMPLATE_NAME="my-app-launch-template"
ASG_NAME="my-app-asg"
REGION="us-east-1"
# =======================================================

# Ensure GitHub token is set
if [ -z "$GITHUB_TOKEN" ]; then
  echo "🔑 Please enter your GitHub Personal Access Token (PAT):"
  read -s GITHUB_TOKEN
  export GITHUB_TOKEN
fi

echo "🚀 Step 1: Initializing Packer Plugins..."
packer init template.pkr.hcl

echo "🚀 Step 2: Building AMI with Packer..."
packer build -var "github_token=$GITHUB_TOKEN" -machine-readable template.pkr.hcl | tee packer_output.txt

# Extract AMI ID from Packer output
AMI_ID=$(grep -E "amazon-ebs.ubuntu: AMIs were created:" packer_output.txt | cut -d' ' -f6 | cut -d'\' -f1 | tr -d '\r')

if [ -z "$AMI_ID" ]; then
  echo "❌ Error: Could not extract AMI ID from Packer build."
  exit 1
fi

echo "✅ AMI Created Successfully: $AMI_ID"

echo "🚀 Step 3: Creating New Launch Template Version..."
NEW_VERSION=$(aws ec2 create-launch-template-version \
    --launch-template-name "$LAUNCH_TEMPLATE_NAME" \
    --launch-template-data "{\"ImageId\":\"$AMI_ID\"}" \
    --query "LaunchTemplateVersion.VersionNumber" --output text --region "$REGION")

aws ec2 modify-launch-template \
    --launch-template-name "$LAUNCH_TEMPLATE_NAME" \
    --default-version "$NEW_VERSION" --region "$REGION" > /dev/null

echo "✅ Launch Template ($LAUNCH_TEMPLATE_NAME) updated to Version $NEW_VERSION."

echo "🚀 Step 4: Updating Auto Scaling Group..."
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "$ASG_NAME" \
    --launch-template "LaunchTemplateName=$LAUNCH_TEMPLATE_NAME,Version=\$Default" \
    --region "$REGION"

echo "🚀 Step 5: Triggering ASG Rolling Instance Refresh..."
aws autoscaling start-instance-refresh \
    --auto-scaling-group-name "$ASG_NAME" \
    --region "$REGION" > /dev/null

echo "🎉 DEPLOYMENT COMPLETE! ASG is replacing EC2 instances with the newly built AMI."
