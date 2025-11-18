# s3 Mobile App

While travelling, my camera roll filled up so quickly that I found myself in a bind: I didn't want to get stuck paying for an ongoing, expensive cloud subscription service, but I also didn't have easy access to a hard drive for offloading photos. My personal solution to this problem is this app. I designed the S3 Mobile App not as a cloud storage alternative, but as a cheap, easy-to-use, temporary storage solution. It lets me quickly dump media from my phone into my own AWS S3 bucket to free up space until I get home. To use this project yourself (on your Android phone), all you'll need is an AWS and Expo account.

## Technical Implementation

### Frontend
- Language: TypeScript
- Framework: React Native 0.81.4, React 19, Expo SDK 54
- Navigation: Expo Router 6 with file-based routing
- State Management: React Native Async Storage
- AWS Integration: AWS SDK v3 (Cognito Identity, Lambda Client)
- Image Handling: Expo Image Picker with camera and gallery support
- Key Features: Direct S3 uploads via pre-signed URLs, unauthenticated Cognito identity provider, native Android permissions handling

### Backend
- Language: Python 3.12
- Compute: AWS Lambda (serverless)
- Storage: Amazon S3 with intelligent lifecycle policies
- Authentication: AWS Cognito Identity Pool (unauthenticated access)
- Key Features: Pre-signed URL generation, timestamp-based file naming, automatic CORS handling

### Infrastructure
- Infrastructure as Code: AWS CloudFormation
- Cloud Provider: AWS (S3, Lambda, Cognito, IAM)
- Deployment Strategy: Automated CloudFormation stack deployment
- Mobile Deployment: Expo Application Services (EAS) for Android builds
- CI/CD: Automated build pipeline with environment secret management

## Key Achievements

- **Serverless Architecture**: Designed and implemented a fully serverless mobile upload system using AWS Lambda and S3, eliminating server maintenance costs and achieving near-infinite scalability with pay-per-use pricing.

- **Infrastructure as Code**: Built a complete CloudFormation template that provisions all AWS resources (S3 buckets, Lambda functions, Cognito Identity Pools, IAM roles) with a single command, enabling reproducible deployments and version-controlled infrastructure.

- **Cost-Optimized Storage Strategy**: Implemented intelligent S3 lifecycle policies that automatically transition photos to Deep Archive after 5 days and delete after 1 year, reducing storage costs by up to 95% compared to standard S3 pricing.

- **Secure Pre-Signed URL Pattern**: Developed a secure upload mechanism using Lambda-generated pre-signed URLs with configurable expiration times, allowing direct client-to-S3 uploads without exposing AWS credentials in the mobile app.

- **Modern React Native Development**: Leveraged the latest React 19 and Expo SDK 54 with Expo Router for file-based routing, providing a maintainable codebase with type-safe navigation and automatic code splitting.

- **Unauthenticated Identity Architecture**: Implemented AWS Cognito Identity Pool with unauthenticated access, providing temporary AWS credentials to mobile clients without requiring user authentication, perfect for personal use cases.

- **Automated Deployment Pipeline**: Created comprehensive setup scripts that automate the entire deployment process from AWS infrastructure provisioning to EAS configuration and secret management, reducing setup time from hours to minutes.

- **Cross-Platform Compatibility**: Built with React Native and Expo for easy deployment to both Android and iOS platforms, with comprehensive permission handling for camera and photo library access.

## Architecture Highlights

### Image Upload Pipeline
1. User selects images from gallery or camera using Expo Image Picker
2. React Native app authenticates with AWS Cognito Identity Pool (unauthenticated)
3. App invokes Lambda function via AWS SDK with filename and metadata
4. Lambda function generates pre-signed S3 PUT URL with 1-hour expiration
5. App performs direct HTTP PUT to S3 using pre-signed URL
6. S3 stores image with timestamp-prefixed key to prevent overwrites
7. After 5 days, S3 lifecycle policy automatically transitions to Deep Archive
8. After 1 year, images are automatically deleted to minimize costs

### Infrastructure Deployment Pipeline
1. Developer runs automated setup script with configuration parameters
2. Lambda deployment package is zipped and uploaded to staging S3 bucket
3. CloudFormation stack creates all resources with proper IAM permissions
4. Stack outputs (Identity Pool ID, Lambda name, bucket name) are extracted
5. Environment variables are injected into frontend `.env` file
6. EAS project is configured with Expo username and secrets
7. Secrets are pushed to EAS for secure cloud builds
8. Developer can build APK via EAS or run locally with Expo Go

### Security Features
- **No Credentials in Code**: AWS credentials never stored in mobile app; Cognito provides temporary credentials
- **Least Privilege IAM**: Cognito role only has permission to invoke specific Lambda function
- **Pre-Signed URL Expiration**: Upload URLs expire after 1 hour to prevent unauthorized access
- **Public Access Blocking**: S3 bucket configured to block all public access by default
- **CORS Configuration**: Restricted CORS policy allowing only PUT/POST from specific origins
- **Environment Secret Management**: Sensitive configuration stored in EAS secrets, never committed to git

# Setup Guide

This guide will help you set up your own instance of the S3 Mobile Storage app with your AWS account and Expo account.

## Prerequisites

Before running the setup script, make sure you have:

1. **AWS Account**
   - An active AWS account
   - AWS CLI installed and configured
   - Appropriate permissions to create S3 buckets, Lambda functions, Cognito Identity Pools, and IAM roles

2. **Expo Account**
   - Free account at [expo.dev](https://expo.dev)
   - Note your username (you'll need it during setup)

3. **Required Software**
   - Node.js (v16 or later)
   - npm (comes with Node.js)
   - Git
   - AWS CLI
   - jq (for JSON parsing)

### Installing Prerequisites

#### macOS
```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install node awscli jq
```

#### Ubuntu/Debian Linux
```bash
sudo apt update
sudo apt install nodejs npm awscli jq
```

#### Windows
1. Install [Node.js](https://nodejs.org/)
2. Install [AWS CLI](https://aws.amazon.com/cli/)
3. Install [jq](https://stedolan.github.io/jq/download/)

## Setup Instructions

### Step 1: Configure AWS CLI

If you haven't configured AWS CLI yet:

```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `eu-west-2`)
- Default output format (use `json`)

### Step 2: Clone the Repository

```bash
git clone <your-repo-url>
cd s3-mobile-storage
```

### Step 3: Run the Setup Script

Make the script executable and run it:

```bash
chmod +x setup.sh
./setup.sh
```

The script will:
1. ✅ Check all prerequisites
2. ✅ Prompt you for configuration details
3. ✅ Deploy AWS infrastructure (S3, Lambda, Cognito)
4. ✅ Configure your frontend app
5. ✅ Set up EAS project and secrets

### Step 4: Follow the Prompts

The script will ask for:

- **AWS Region**: Where to deploy resources (default: `eu-west-2`)
- **Stack Name**: CloudFormation stack name (default: `s3-mobile-stack`)
- **Image Bucket Name**: Unique S3 bucket for images (must be globally unique)
- **Lambda Bucket Name**: Unique S3 bucket for Lambda code (must be globally unique)
- **Expo Username**: Your Expo account username

💡 **Tip**: For bucket names, the script suggests names. You can accept these or provide your own.

### Step 5: EAS Login

If not already logged in, the script will prompt you to log into EAS:

```bash
eas login
```

Enter your Expo credentials.

## What the Script Does

### Backend (AWS)
1. Creates an S3 bucket for storing uploaded images
2. Deploys a Lambda function that generates pre-signed URLs
3. Sets up a Cognito Identity Pool for authentication
4. Configures appropriate IAM roles and permissions
5. Sets up CORS and lifecycle policies on the S3 bucket

### Frontend (Expo)
1. Installs npm dependencies
2. Creates a `.env` file with AWS credentials
3. Updates `config/aws.ts` to use environment variables
4. Configures `app.json` with your Expo username
5. Updates `eas.json` for environment variable support
6. Pushes secrets to EAS for cloud builds

## Testing Your Setup

### Test Locally

```bash
cd frontend
npm start
```

This will start the Expo development server. You can:
- Press `a` to open on Android emulator
- Scan QR code with Expo Go app on your phone

### Build APK

```bash
cd frontend
eas build --platform android --profile preview
```

This creates an installable APK file. After the build completes (usually 10-20 minutes), you can download it from your EAS dashboard.


## Project Structure

```
s3-mobile-storage/
├── backend/
│   ├── cloudformation-template.yaml  # AWS infrastructure
│   ├── lambda_function.py           # Pre-signed URL generator
│   └── deploy.sh                    # Backend-only deploy script
├── frontend/
│   ├── app.json                     # Expo configuration
│   ├── eas.json                     # EAS build configuration
│   ├── package.json                 # Dependencies
│   ├── .env                         # Local environment variables (generated)
│   └── config/
│       └── aws.ts                   # AWS configuration (generated)
└── setup.sh                         # Complete setup script
```

## Environment Variables

The script creates these environment variables:

- `EXPO_PUBLIC_IDENTITY_POOL_ID`: Cognito Identity Pool ID
- `EXPO_PUBLIC_REGION`: AWS region
- `EXPO_PUBLIC_LAMBDA_FUNCTION_NAME`: Lambda function name
- `EXPO_PUBLIC_BUCKET_NAME`: S3 bucket name

These are:
- Stored in `frontend/.env` for local development
- Pushed to EAS secrets for cloud builds
- Accessed via `process.env` in your app code

## Troubleshooting

### "Experience with id 'xxx' does not exist"
This means there's leftover EAS metadata from a previous setup. To fix:

```bash
# Run the cleanup script
chmod +x clean-eas.sh
./clean-eas.sh

# Then run setup again
./setup.sh
```

Or manually:
```bash
cd frontend
rm -rf .expo
# Reset app.json to template (remove projectId)
# Then run setup.sh again
```

### "Bucket already exists"
S3 bucket names must be globally unique. If you get this error, choose a different bucket name.

### "AWS CLI not configured"
Run `aws configure` and enter your credentials.

### "Not logged into EAS"
Run `eas login` and enter your Expo credentials.

### "Permission denied"
Make sure the script is executable: `chmod +x setup.sh`

### Build fails on EAS
Check that secrets were pushed correctly:
```bash
cd frontend
eas env:list
```

You should see all four `EXPO_PUBLIC_*` variables.

### Local development shows undefined values
Make sure you're in the `frontend` directory and `.env` file exists with all values filled in.

## Costs

This setup uses AWS services that may incur costs:

- **S3**: Pay for storage and requests (very low for personal use)
- **Lambda**: Free tier includes 1M requests/month
- **Cognito**: Free tier includes 50,000 MAUs
- **CloudFormation**: Free (only charges for resources it creates)

For typical personal use, you'll likely stay within AWS Free Tier limits.

## Cleaning Up

To completely remove all AWS resources:

```bash
cd backend
aws cloudformation delete-stack --stack-name s3-mobile-stack --region eu-west-2
aws s3 rb s3://your-lambda-bucket-name --force
```

Replace the stack name and region with your values.

## Security Notes

1. **Never commit `.env` files** - They contain sensitive credentials
2. The `.gitignore` file should include `.env`
3. EAS secrets are encrypted and stored securely
4. The S3 bucket blocks all public access by default
5. Cognito Identity Pool uses unauthenticated access with limited permissions

## Getting Help

If you encounter issues:

1. Check the troubleshooting section above
2. Review the script output for specific error messages
3. Verify all prerequisites are installed
4. Check AWS CloudFormation console for stack deployment status
5. Check EAS dashboard for build logs

## Next Steps

After setup:

1. Customize the app UI in `frontend/app/`
2. Modify S3 lifecycle rules in `cloudformation-template.yaml`
3. Adjust Lambda timeout or memory if needed
4. Add additional features like image compression or thumbnails

## Contributing

Feel free to submit issues or pull requests to improve this setup process!