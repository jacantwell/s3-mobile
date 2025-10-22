// config/aws.ts
// AWS Configuration for the Image Upload App
// Fill in these values after deploying your CloudFormation stack

export const AWS_CONFIG = {
  // Get this from CloudFormation stack outputs: IdentityPoolId
  IDENTITY_POOL_ID: '',
  
  // Get this from CloudFormation stack outputs: Region
  REGION: 'eu-west-2',
  
  // Get this from CloudFormation stack outputs: LambdaFunctionName
  LAMBDA_FUNCTION_NAME: 's3-mobile-stack-PresignedUrlGenerator',
  
  // Get this from CloudFormation stack outputs: BucketName
  BUCKET_NAME: 's3-mobile-storage'
};