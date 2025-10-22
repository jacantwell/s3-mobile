import { CognitoIdentityClient } from '@aws-sdk/client-cognito-identity';
import { fromCognitoIdentityPool } from '@aws-sdk/credential-provider-cognito-identity';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { AWS_CONFIG } from '@/config/aws';
import { PresignedUrlResponse } from '@/types/upload';

// Initialize Cognito credentials provider
const credentialsProvider = fromCognitoIdentityPool({
  client: new CognitoIdentityClient({ region: AWS_CONFIG.REGION }),
  identityPoolId: AWS_CONFIG.IDENTITY_POOL_ID,
});

// Initialize Lambda client with Cognito credentials
const lambdaClient = new LambdaClient({
  region: AWS_CONFIG.REGION,
  credentials: credentialsProvider,
});

/**
 * Request a pre-signed URL from Lambda for uploading a file
 */
export async function getPresignedUrl(
  fileName: string,
  contentType: string
): Promise<PresignedUrlResponse> {
  try {
    const payload = {
      fileName,
      contentType,
    };

    const command = new InvokeCommand({
      FunctionName: AWS_CONFIG.LAMBDA_FUNCTION_NAME,
      Payload: new TextEncoder().encode(JSON.stringify(payload)),
    });

    const response = await lambdaClient.send(command);

    if (!response.Payload) {
      throw new Error('No response from Lambda function');
    }

    const payloadString = new TextDecoder().decode(response.Payload);
    const result = JSON.parse(payloadString);

    // Handle both direct invoke response and API Gateway format
    if (result.statusCode) {
      const body = JSON.parse(result.body);
      if (result.statusCode !== 200) {
        throw new Error(body.error || 'Failed to get presigned URL');
      }
      return body;
    }

    return result;
  } catch (error) {
    console.error('Error getting presigned URL:', error);
    throw error;
  }
}

/**
 * Upload file to S3 using pre-signed URL
 */
export async function uploadToS3(
  presignedUrl: string,
  fileUri: string,
  contentType: string,
  onProgress?: (progress: number) => void
): Promise<void> {
  try {
    // Read file as blob
    const response = await fetch(fileUri);
    const blob = await response.blob();

    // Upload using XMLHttpRequest to track progress
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      xhr.upload.addEventListener('progress', (event) => {
        if (event.lengthComputable && onProgress) {
          const progress = (event.loaded / event.total) * 100;
          onProgress(progress);
        }
      });

      xhr.addEventListener('load', () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve();
        } else {
          reject(new Error(`Upload failed with status ${xhr.status}`));
        }
      });

      xhr.addEventListener('error', () => {
        reject(new Error('Network error during upload'));
      });

      xhr.addEventListener('abort', () => {
        reject(new Error('Upload aborted'));
      });

      console.log("content type:", contentType);

      xhr.open('PUT', presignedUrl);
      // xhr.setRequestHeader('Content-Type', "'image/jpeg'");
      xhr.send(blob);
    });
  } catch (error) {
    console.error('Error uploading to S3:', error);
    throw error;
  }
}