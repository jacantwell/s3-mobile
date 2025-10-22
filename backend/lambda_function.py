import json
import os
import boto3
from datetime import datetime
from botocore.exceptions import ClientError
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize S3 client
s3_client = boto3.client('s3')

# Get environment variables
BUCKET_NAME = os.environ.get('BUCKET_NAME')
URL_EXPIRATION = int(os.environ.get('URL_EXPIRATION', 3600))


def lambda_handler(event, context):
    """
    Generate a pre-signed URL for uploading an image to S3.
    
    Expected input (direct Lambda invoke from Cognito):
    {
        "fileName": "photo.jpg",
        "contentType": "image/jpeg"  # optional
    }
    
    Returns:
    {
        "uploadUrl": "https://...",
        "key": "2025-10-21T10-30-00-photo.jpg",
        "bucket": "bucket-name"
    }
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Handle both direct Lambda invocation and API Gateway format
        if isinstance(event.get('body'), str):
            # API Gateway format
            body = json.loads(event['body'])
        else:
            # Direct Lambda invocation
            body = event
        
        # Extract parameters
        file_name = body.get('fileName')
        # content_type = body.get('contentType', 'image/jpeg')
        
        # Validate input
        if not file_name:
            logger.error("fileName parameter is missing")
            return create_response(400, {
                'error': 'fileName is required'
            })
        
        # Generate unique key with timestamp to avoid overwrites
        timestamp = datetime.utcnow().strftime('%Y-%m-%dT%H-%M-%S')
        key = f"{timestamp}-{file_name}"
        
        logger.info(f"Generating pre-signed URL for key: {key}")
        
        # Generate pre-signed URL for PUT operation
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': key,
                # 'ContentType': content_type
            },
            ExpiresIn=URL_EXPIRATION,
            HttpMethod='PUT'
        )
        
        logger.info(f"Successfully generated pre-signed URL for {key}")
        
        return create_response(200, {
            'uploadUrl': presigned_url,
            'key': key,
            'bucket': BUCKET_NAME
        })
        
    except ClientError as e:
        logger.error(f"AWS ClientError: {str(e)}")
        return create_response(500, {
            'error': 'Failed to generate upload URL',
            'message': str(e)
        })
    
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })


def create_response(status_code, body):
    """Helper function to create Lambda response with proper headers"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'POST, OPTIONS'
        },
        'body': json.dumps(body)
    }