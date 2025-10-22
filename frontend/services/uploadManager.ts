import { UploadTask } from '@/types/upload';
import { getPresignedUrl, uploadToS3 } from './aws';
import { saveUploadQueue } from './storage';
import { File } from 'expo-file-system';

class UploadManager {
  private queue: UploadTask[] = [];
  private isProcessing = false;
  private listeners: ((tasks: UploadTask[]) => void)[] = [];
  private maxConcurrent = 3;
  private activeUploads = 0;

  /**
   * Subscribe to queue updates
   */
  subscribe(callback: (tasks: UploadTask[]) => void): () => void {
    this.listeners.push(callback);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== callback);
    };
  }

  /**
   * Notify all listeners of queue changes
   */
  private notifyListeners() {
    this.listeners.forEach((listener) => listener([...this.queue]));
  }

  /**
   * Initialize queue with persisted tasks
   */
  async initialize(tasks: UploadTask[]) {
    this.queue = tasks;
    this.notifyListeners();
    await this.processQueue();
  }

  /**
   * Add images to upload queue
   */
  async addToQueue(assets: { uri: string; fileName: string; mimeType: string }[]) {
    for (const asset of assets) {
      try {
        // Get file size using the new, non-deprecated API from Expo
        const file = new File(asset.uri);

        const fileInfo = file.info()

        if (!fileInfo) {
          console.warn(`Could not retrieve file info for ${asset.fileName}, skipping asset.`);
          throw new Error('File info not available');
        }

        // The new API provides better types, so we can safely access .size
        const fileSize = fileInfo.exists ? (fileInfo.size ?? 0) : 0;

        const task: UploadTask = {
          id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
          uri: asset.uri,
          fileName: asset.fileName,
          fileSize,
          mimeType: asset.mimeType,
          status: 'pending',
          progress: 0,
          createdAt: Date.now(),
        };
        this.queue.push(task);
      } catch (error) {
        console.error(`Could not get file info for ${asset.fileName}, skipping asset.`, error);
      }
    }

    this.notifyListeners();
    await saveUploadQueue(this.queue);
    await this.processQueue();
  }

  /**
   * Process the upload queue
   */
  private async processQueue() {
    if (this.isProcessing) return;
    this.isProcessing = true;

    while (this.queue.some((t) => t.status === 'pending' || t.status === 'failed')) {
      // Find next task to upload
      const task = this.queue.find((t) => t.status === 'pending' || t.status === 'failed');
      
      if (!task) break;

      // Wait if we're at max concurrent uploads
      while (this.activeUploads >= this.maxConcurrent) {
        await new Promise((resolve) => setTimeout(resolve, 100));
      }

      // Upload without waiting (fire and forget for concurrency)
      this.uploadTask(task);
    }

    this.isProcessing = false;
  }

  /**
   * Upload a single task
   */
  private async uploadTask(task: UploadTask) {
    this.activeUploads++;
    
    try {
      // Update status to uploading
      task.status = 'uploading';
      task.progress = 0;
      task.error = undefined;
      this.notifyListeners();
      await saveUploadQueue(this.queue);

      // Get pre-signed URL
      const { uploadUrl, key } = await getPresignedUrl(task.fileName, task.mimeType);
      task.s3Key = key;

      // Upload to S3
      await uploadToS3(uploadUrl, task.uri, task.mimeType, (progress) => {
        task.progress = progress;
        this.notifyListeners();
      });

      // Mark as completed
      task.status = 'completed';
      task.progress = 100;
      task.uploadedAt = Date.now();
      this.notifyListeners();
      await saveUploadQueue(this.queue);
    } catch (error) {
      console.error(`Upload failed for ${task.fileName}:`, error);
      task.status = 'failed';
      task.error = error instanceof Error ? error.message : 'Upload failed';
      this.notifyListeners();
      await saveUploadQueue(this.queue);
    } finally {
      this.activeUploads--;
    }
  }

  /**
   * Retry failed uploads
   */
  async retryFailed() {
    // const failedTasks = this.queue.filter((t) => t.status === 'failed');
    // failedTasks.forEach((task) => {
    //   task.status = 'pending';
    //   task.progress = 0;
    //   task.error = undefined;
    // });
    
    // this.notifyListeners();
    // await saveUploadQueue(this.queue);
    // await this.processQueue();
  }

  /**
   * Retry a specific task
   */
  async retryTask(taskId: string) {
    const task = this.queue.find((t) => t.id === taskId);
    if (task && task.status === 'failed') {
      task.status = 'pending';
      task.progress = 0;
      task.error = undefined;
      this.notifyListeners();
      await saveUploadQueue(this.queue);
      await this.processQueue();
    }
  }

  /**
   * Remove completed uploads from queue
   */
  async clearCompleted() {
    this.queue = this.queue.filter((t) => t.status !== 'completed');
    this.notifyListeners();
    await saveUploadQueue(this.queue);
  }

  /**
   * Remove a specific task
   */
  async removeTask(taskId: string) {
    this.queue = this.queue.filter((t) => t.id !== taskId);
    this.notifyListeners();
    await saveUploadQueue(this.queue);
  }

  /**
   * Get current queue
   */
  getQueue(): UploadTask[] {
    return [...this.queue];
  }

  /**
   * Get upload statistics
   */
  getStats() {
    return {
      total: this.queue.length,
      pending: this.queue.filter((t) => t.status === 'pending').length,
      uploading: this.queue.filter((t) => t.status === 'uploading').length,
      completed: this.queue.filter((t) => t.status === 'completed').length,
      failed: this.queue.filter((t) => t.status === 'failed').length,
    };
  }
}

// Singleton instance
export const uploadManager = new UploadManager();
