#!/bin/bash

# Complete Setup Script for S3 Mobile Storage App
# This script sets up both backend AWS infrastructure and frontend Expo configuration

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          S3 Mobile Storage App - Complete Setup Script         ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to prompt for input with default value
prompt_with_default() {
    local prompt=$1
    local default=$2
    local varname=$3
    
    echo -e "${YELLOW}$prompt${NC}"
    if [ -n "$default" ]; then
        echo -e "${BLUE}(Press Enter to use default: $default)${NC}"
    fi
    read -r input
    if [ -z "$input" ]; then
        eval "$varname='$default'"
    else
        eval "$varname='$input'"
    fi
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists aws; then
    echo -e "${RED}✗ AWS CLI is not installed${NC}"
    echo "Please install it from: https://aws.amazon.com/cli/"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI is installed${NC}"

if ! command_exists node; then
    echo -e "${RED}✗ Node.js is not installed${NC}"
    echo "Please install it from: https://nodejs.org/"
    exit 1
fi
echo -e "${GREEN}✓ Node.js is installed${NC}"

if ! command_exists npm; then
    echo -e "${RED}✗ npm is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ npm is installed${NC}"

# Check if logged into AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ Not logged into AWS CLI${NC}"
    echo "Please run: aws configure"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI is configured${NC}"

# Check for EAS CLI
if ! command_exists eas; then
    echo -e "${YELLOW}⚠ EAS CLI not found. Installing...${NC}"
    npm install -g eas-cli
    echo -e "${GREEN}✓ EAS CLI installed${NC}"
else
    echo -e "${GREEN}✓ EAS CLI is installed${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                    CONFIGURATION SETUP${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Get configuration from user
prompt_with_default "Enter AWS Region:" "eu-west-2" AWS_REGION
prompt_with_default "Enter CloudFormation Stack Name:" "s3-mobile-stack" STACK_NAME
prompt_with_default "Enter S3 Bucket Name for images (must be globally unique):" "s3-mobile-storage" IMAGE_BUCKET_NAME
prompt_with_default "Enter S3 Bucket Name for Lambda code (must be globally unique):" "s3-mobile-lambda" LAMBDA_CODE_BUCKET

echo ""
echo -e "${YELLOW}Enter your Expo account username (for EAS builds):${NC}"
read -r EXPO_USERNAME

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Configuration Summary:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo "AWS Region: $AWS_REGION"
echo "Stack Name: $STACK_NAME"
echo "Image Bucket: $IMAGE_BUCKET_NAME"
echo "Lambda Bucket: $LAMBDA_CODE_BUCKET"
echo "Expo Username: $EXPO_USERNAME"
echo ""
read -p "Press Enter to continue or Ctrl+C to abort..."

# ============================================================
# PART 1: DEPLOY BACKEND INFRASTRUCTURE
# ============================================================

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           PART 1: DEPLOYING AWS INFRASTRUCTURE${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if required backend files exist
if [ ! -f "backend/lambda_function.py" ]; then
    echo -e "${RED}Error: backend/lambda_function.py not found${NC}"
    exit 1
fi

if [ ! -f "backend/cloudformation-template.yaml" ]; then
    echo -e "${RED}Error: backend/cloudformation-template.yaml not found${NC}"
    exit 1
fi

cd backend

echo -e "${YELLOW}Step 1/5: Creating Lambda deployment package...${NC}"
TEMP_DIR=$(mktemp -d)
cp lambda_function.py "$TEMP_DIR/"
cd "$TEMP_DIR"
zip -q -r lambda_function.zip lambda_function.py
cd - > /dev/null
echo -e "${GREEN}✓ Lambda package created${NC}"

echo -e "${YELLOW}Step 2/5: Creating S3 bucket for Lambda code...${NC}"
if aws s3 ls "s3://$LAMBDA_CODE_BUCKET" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb "s3://$LAMBDA_CODE_BUCKET" --region "$AWS_REGION"
    echo -e "${GREEN}✓ Created bucket: $LAMBDA_CODE_BUCKET${NC}"
else
    echo -e "${GREEN}✓ Bucket already exists: $LAMBDA_CODE_BUCKET${NC}"
fi

echo -e "${YELLOW}Step 3/5: Uploading Lambda package to S3...${NC}"
aws s3 cp "$TEMP_DIR/lambda_function.zip" "s3://$LAMBDA_CODE_BUCKET/lambda_function.zip" --region "$AWS_REGION"
echo -e "${GREEN}✓ Lambda package uploaded${NC}"

rm -rf "$TEMP_DIR"

echo -e "${YELLOW}Step 4/5: Deploying CloudFormation stack...${NC}"
echo "This may take several minutes..."
aws cloudformation deploy \
    --template-file cloudformation-template.yaml \
    --stack-name "$STACK_NAME" \
    --parameter-overrides \
        BucketName="$IMAGE_BUCKET_NAME" \
        LambdaCodeS3Bucket="$LAMBDA_CODE_BUCKET" \
        LambdaCodeS3Key="lambda_function.zip" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$AWS_REGION"

echo -e "${GREEN}✓ CloudFormation stack deployed${NC}"

echo -e "${YELLOW}Step 5/5: Retrieving stack outputs...${NC}"
OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs' \
    --output json)

# Extract values from outputs
IDENTITY_POOL_ID=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="IdentityPoolId") | .OutputValue')
LAMBDA_FUNCTION_NAME=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="LambdaFunctionName") | .OutputValue')
BUCKET_NAME=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="BucketName") | .OutputValue')
REGION=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="Region") | .OutputValue')

echo -e "${GREEN}✓ Stack outputs retrieved${NC}"
echo ""
echo -e "${GREEN}AWS Infrastructure Details:${NC}"
echo "  Identity Pool ID: $IDENTITY_POOL_ID"
echo "  Lambda Function: $LAMBDA_FUNCTION_NAME"
echo "  Bucket Name: $BUCKET_NAME"
echo "  Region: $REGION"

cd ..

# ============================================================
# PART 2: CONFIGURE FRONTEND
# ============================================================

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           PART 2: CONFIGURING FRONTEND APP${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

cd frontend

echo -e "${YELLOW}Step 1/5: Installing dependencies...${NC}"
npm install
echo -e "${GREEN}✓ Dependencies installed${NC}"

echo -e "${YELLOW}Step 2/5: Creating .env file...${NC}"
cat > .env << EOF
# AWS Configuration - Generated by setup script
EXPO_PUBLIC_IDENTITY_POOL_ID=$IDENTITY_POOL_ID
EXPO_PUBLIC_REGION=$REGION
EXPO_PUBLIC_LAMBDA_FUNCTION_NAME=$LAMBDA_FUNCTION_NAME
EXPO_PUBLIC_BUCKET_NAME=$BUCKET_NAME
EOF
echo -e "${GREEN}✓ .env file created${NC}"

echo -e "${YELLOW}Step 3/5: Updating aws.ts configuration...${NC}"
cat > config/aws.ts << EOF
// config/aws.ts
// AWS Configuration for the Image Upload App
// Auto-generated by setup script

export const AWS_CONFIG = {
  // Cognito Identity Pool ID
  IDENTITY_POOL_ID: process.env.EXPO_PUBLIC_IDENTITY_POOL_ID ?? '',
  
  // AWS Region
  REGION: process.env.EXPO_PUBLIC_REGION ?? '$REGION',
  
  // Lambda Function Name
  LAMBDA_FUNCTION_NAME: process.env.EXPO_PUBLIC_LAMBDA_FUNCTION_NAME ?? '',
  
  // S3 Bucket Name
  BUCKET_NAME: process.env.EXPO_PUBLIC_BUCKET_NAME ?? ''
};
EOF
echo -e "${GREEN}✓ aws.ts updated${NC}"

echo -e "${YELLOW}Step 4/5: Updating app.json (temporary - will be finalized after EAS init)...${NC}"
# First update with package name, but leave projectId as placeholder
cat > app.json << EOF
{
  "expo": {
    "name": "S3 Mobile Storage",
    "slug": "s3-mobile-storage",
    "version": "1.0.0",
    "main": "expo-router/entry",
    "android": {
      "package": "com.${EXPO_USERNAME}.s3mobilestorage",
      "permissions": [
        "android.permission.INTERNET",
        "android.permission.READ_MEDIA_IMAGES",
        "android.permission.WAKE_LOCK",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.CAMERA",
        "android.permission.RECORD_AUDIO"
      ]
    },
    "plugins": [
      [
        "expo-image-picker",
        {
          "photosPermission": "Allow \$(PRODUCT_NAME) to access your photos.",
          "cameraPermission": "Allow \$(PRODUCT_NAME) to use your camera."
        }
      ]
    ]
  }
}
EOF
echo -e "${GREEN}✓ app.json updated with package name${NC}"

echo -e "${YELLOW}Step 5/5: Updating eas.json for environment variables...${NC}"
cat > eas.json << EOF
{
  "cli": {
    "version": ">= 16.26.0",
    "appVersionSource": "remote"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "env": {
        "EXPO_PUBLIC_IDENTITY_POOL_ID": "EXPO_PUBLIC_IDENTITY_POOL_ID",
        "EXPO_PUBLIC_REGION": "EXPO_PUBLIC_REGION",
        "EXPO_PUBLIC_LAMBDA_FUNCTION_NAME": "EXPO_PUBLIC_LAMBDA_FUNCTION_NAME",
        "EXPO_PUBLIC_BUCKET_NAME": "EXPO_PUBLIC_BUCKET_NAME"
      }
    },
    "preview": {
      "distribution": "internal",
      "env": {
        "EXPO_PUBLIC_IDENTITY_POOL_ID": "EXPO_PUBLIC_IDENTITY_POOL_ID",
        "EXPO_PUBLIC_REGION": "EXPO_PUBLIC_REGION",
        "EXPO_PUBLIC_LAMBDA_FUNCTION_NAME": "EXPO_PUBLIC_LAMBDA_FUNCTION_NAME",
        "EXPO_PUBLIC_BUCKET_NAME": "EXPO_PUBLIC_BUCKET_NAME"
      }
    },
    "production": {
      "autoIncrement": true,
      "env": {
        "EXPO_PUBLIC_IDENTITY_POOL_ID": "EXPO_PUBLIC_IDENTITY_POOL_ID",
        "EXPO_PUBLIC_REGION": "EXPO_PUBLIC_REGION",
        "EXPO_PUBLIC_LAMBDA_FUNCTION_NAME": "EXPO_PUBLIC_LAMBDA_FUNCTION_NAME",
        "EXPO_PUBLIC_BUCKET_NAME": "EXPO_PUBLIC_BUCKET_NAME"
      }
    }
  },
  "submit": {
    "production": {}
  }
}
EOF
echo -e "${GREEN}✓ eas.json updated${NC}"

# ============================================================
# PART 3: SETUP EAS PROJECT
# ============================================================

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           PART 3: SETTING UP EAS PROJECT${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Checking EAS login status...${NC}"
if ! eas whoami &> /dev/null; then
    echo -e "${YELLOW}Please log in to your Expo account:${NC}"
    eas login
else
    echo -e "${GREEN}✓ Already logged into EAS${NC}"
fi

echo ""
echo -e "${YELLOW}Initializing EAS project...${NC}"
echo "If prompted, use the project ID: $PROJECT_ID"
eas init --id "$PROJECT_ID" || echo -e "${YELLOW}Project may already be initialized${NC}"

echo ""
echo -e "${YELLOW}Pushing environment variables to EAS secrets...${NC}"
eas env:push production --path .env --force
eas env:push preview --path .env --force
echo -e "${GREEN}✓ Secrets pushed to EAS${NC}"

cd ..

# ============================================================
# COMPLETION
# ============================================================

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    SETUP COMPLETE! 🎉${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}Your AWS Infrastructure:${NC}"
echo "  ✓ S3 Bucket: $BUCKET_NAME"
echo "  ✓ Lambda Function: $LAMBDA_FUNCTION_NAME"
echo "  ✓ Cognito Identity Pool: $IDENTITY_POOL_ID"
echo "  ✓ Region: $REGION"
echo ""

echo -e "${BLUE}Your Frontend Configuration:${NC}"
echo "  ✓ .env file created with AWS credentials"
echo "  ✓ aws.ts updated to use environment variables"
echo "  ✓ app.json configured for your Expo account"
echo "  ✓ EAS secrets uploaded"
echo ""

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}                    NEXT STEPS${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}To test locally:${NC}"
echo "  cd frontend"
echo "  npm start"
echo ""
echo -e "${BLUE}To build an APK:${NC}"
echo "  cd frontend"
echo "  eas build --platform android --profile preview"
echo ""
echo -e "${GREEN}The APK will be available in your EAS dashboard after build completes.${NC}"
echo -e "${GREEN}Visit: https://expo.dev/accounts/$EXPO_USERNAME/projects${NC}"
echo ""

echo -e "${YELLOW}Important files created:${NC}"
echo "  • frontend/.env (local environment variables)"
echo "  • frontend/config/aws.ts (updated AWS config)"
echo "  • frontend/app.json (updated with your settings)"
echo "  • frontend/eas.json (updated for EAS builds)"
echo ""

echo -e "${RED}⚠ SECURITY NOTE:${NC}"
echo "  The .env file contains sensitive information."
echo "  Make sure it's in your .gitignore!"
echo ""