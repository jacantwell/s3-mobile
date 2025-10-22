import AsyncStorage from '@react-native-async-storage/async-storage';
import { UploadTask } from '@/types/upload';

const UPLOAD_QUEUE_KEY = 'upload_queue';

/**
 * Save upload queue to persistent storage
 */
export async function saveUploadQueue(tasks: UploadTask[]): Promise<void> {
  try {
    await AsyncStorage.setItem(UPLOAD_QUEUE_KEY, JSON.stringify(tasks));
  } catch (error) {
    console.error('Error saving upload queue:', error);
  }
}

/**
 * Load upload queue from persistent storage
 */
export async function loadUploadQueue(): Promise<UploadTask[]> {
  try {
    const data = await AsyncStorage.getItem(UPLOAD_QUEUE_KEY);
    if (data) {
      return JSON.parse(data);
    }
    return [];
  } catch (error) {
    console.error('Error loading upload queue:', error);
    return [];
  }
}

/**
 * Clear upload queue from storage
 */
export async function clearUploadQueue(): Promise<void> {
  try {
    await AsyncStorage.removeItem(UPLOAD_QUEUE_KEY);
  } catch (error) {
    console.error('Error clearing upload queue:', error);
  }
}