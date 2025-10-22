export interface UploadTask {
  id: string;
  uri: string;
  fileName: string;
  fileSize: number;
  mimeType: string;
  status: 'pending' | 'uploading' | 'completed' | 'failed';
  progress: number;
  error?: string;
  s3Key?: string;
  createdAt: number;
  uploadedAt?: number;
}

export interface PresignedUrlResponse {
  uploadUrl: string;
  key: string;
  bucket: string;
}

export interface UploadStats {
  total: number;
  pending: number;
  uploading: number;
  completed: number;
  failed: number;
}