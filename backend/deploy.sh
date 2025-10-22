#!/bin/bash

# Deployment script for Image Upload Infrastructure
# This script packages and deploys the Lambda function and CloudFormation stack

set -e  # Exit on error

# Configuration - UPDATE THESE VALUES
STACK_NAME="s3-mobile-stack"
IMAGE_BUCKET_NAME="s3-mobile-storage"  # MUST be globally unique
LAMBDA_CODE_BUCKET="s3-mobile-lambda"       # Bucket to store Lambda .zip
REGION="eu-west-2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Image Upload App Deployment ===${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Check if required files exist
if [ ! -f "lambda_function.py" ]; then
    echo -e "${RED}Error: lambda_function.py not found${NC}"
    exit 1
fi

if [ ! -f "cloudformation-template.yaml" ]; then
    echo -e "${RED}Error: cloudformation-template.yaml not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Creating Lambda deployment package...${NC}"
# Create a temporary directory for packaging
TEMP_DIR=$(mktemp -d)
cp lambda_function.py "$TEMP_DIR/"
cd "$TEMP_DIR"
zip -r lambda_function.zip lambda_function.py
cd - > /dev/null

echo -e "${GREEN}✓ Lambda package created${NC}"

echo -e "${YELLOW}Step 2: Creating S3 bucket for Lambda code (if it doesn't exist)...${NC}"
# Check if bucket exists, create if it doesn't
if aws s3 ls "s3://$LAMBDA_CODE_BUCKET" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb "s3://$LAMBDA_CODE_BUCKET" --region "$REGION"
    echo -e "${GREEN}✓ Created bucket: $LAMBDA_CODE_BUCKET${NC}"
else
    echo -e "${GREEN}✓ Bucket already exists: $LAMBDA_CODE_BUCKET${NC}"
fi

echo -e "${YELLOW}Step 3: Uploading Lambda package to S3...${NC}"
aws s3 cp "$TEMP_DIR/lambda_function.zip" "s3://$LAMBDA_CODE_BUCKET/lambda_function.zip" --region "$REGION"
echo -e "${GREEN}✓ Lambda package uploaded${NC}"

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo -e "${YELLOW}Step 4: Deploying CloudFormation stack...${NC}"
aws cloudformation deploy \
    --template-file cloudformation-template.yaml \
    --stack-name "$STACK_NAME" \
    --parameter-overrides \
        BucketName="$IMAGE_BUCKET_NAME" \
        LambdaCodeS3Bucket="$LAMBDA_CODE_BUCKET" \
        LambdaCodeS3Key="lambda_function.zip" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION"

echo -e "${GREEN}✓ CloudFormation stack deployed${NC}"

echo -e "${YELLOW}Step 5: Retrieving stack outputs...${NC}"
OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs' \
    --output json)

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Stack Outputs (save these for your React Native app):"
echo "$OUTPUTS" | jq -r '.[] | "\(.OutputKey): \(.OutputValue)"'

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Copy the IdentityPoolId and LambdaFunctionName values"
echo "2. Use these in your React Native app configuration"
echo "3. Deploy your React Native app"