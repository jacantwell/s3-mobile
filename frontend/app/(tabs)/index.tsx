import 'react-native-get-random-values';
import { useEffect, useState } from 'react';
import { StyleSheet, View, ScrollView, TouchableOpacity, Alert } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { uploadManager } from '@/services/uploadManager';
import { loadUploadQueue } from '@/services/storage';
import { UploadTask } from '@/types/upload';
import { IconSymbol } from '@/components/ui/icon-symbol';

export default function HomeScreen() {
  const [tasks, setTasks] = useState<UploadTask[]>([]);
  const [isSelecting, setIsSelecting] = useState(false);

  useEffect(() => {
    // Load persisted queue on mount
    loadUploadQueue().then((savedTasks) => {
      uploadManager.initialize(savedTasks);
    });

    // Subscribe to queue updates
    const unsubscribe = uploadManager.subscribe(setTasks);
    return unsubscribe;
  }, []);

  const selectImages = async () => {
    try {
      setIsSelecting(true);

      // Request permissions
      const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Denied', 'We need camera roll permissions to upload images.');
        return;
      }

      // Launch image picker
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'],
        allowsMultipleSelection: true,
        quality: 1,
        selectionLimit: 50, // Limit to prevent overwhelming the queue
      });

      if (!result.canceled && result.assets.length > 0) {
        const assets = result.assets.map((asset) => ({
          uri: asset.uri,
          fileName: asset.fileName || `image-${Date.now()}.jpg`,
          mimeType: asset.mimeType || 'image/jpeg',
        }));

        await uploadManager.addToQueue(assets);
      }
    } catch (error) {
      console.error('Error selecting images:', error);
      Alert.alert('Error', 'Failed to select images. Please try again.');
    } finally {
      setIsSelecting(false);
    }
  };

  const stats = uploadManager.getStats();

  return (
    <ThemedView style={styles.container}>
      <ScrollView style={styles.scrollView} contentContainerStyle={styles.scrollContent}>
        {/* Header */}
        <View style={styles.header}>
          <ThemedText type="title" style={styles.title}>
            S3 Image Uploader
          </ThemedText>
          <ThemedText style={styles.subtitle}>
            Select photos to upload to your S3 bucket
          </ThemedText>
        </View>

        {/* Select Images Button */}
        <TouchableOpacity
          style={[styles.selectButton, isSelecting && styles.selectButtonDisabled]}
          onPress={selectImages}
          disabled={isSelecting}
          activeOpacity={0.7}>
          <IconSymbol name="paperplane.fill" size={24} color="#fff" />
          <ThemedText style={styles.selectButtonText}>
            {isSelecting ? 'Selecting...' : 'Select Images'}
          </ThemedText>
        </TouchableOpacity>

        {/* Stats */}
        {tasks.length > 0 && (
          <View style={styles.statsContainer}>
            <View style={styles.statItem}>
              <ThemedText style={styles.statNumber}>{stats.total}</ThemedText>
              <ThemedText style={styles.statLabel}>Total</ThemedText>
            </View>
            <View style={styles.statItem}>
              <ThemedText style={[styles.statNumber, styles.statUploading]}>
                {stats.uploading}
              </ThemedText>
              <ThemedText style={styles.statLabel}>Uploading</ThemedText>
            </View>
            <View style={styles.statItem}>
              <ThemedText style={[styles.statNumber, styles.statCompleted]}>
                {stats.completed}
              </ThemedText>
              <ThemedText style={styles.statLabel}>Completed</ThemedText>
            </View>
            <View style={styles.statItem}>
              <ThemedText style={[styles.statNumber, styles.statFailed]}>
                {stats.failed}
              </ThemedText>
              <ThemedText style={styles.statLabel}>Failed</ThemedText>
            </View>
          </View>
        )}

        {/* Action Buttons */}
        {tasks.length > 0 && (
          <View style={styles.actionButtons}>
            {stats.failed > 0 && (
              <TouchableOpacity
                style={[styles.actionButton, styles.retryButton]}
                onPress={() => uploadManager.retryFailed()}>
                <ThemedText style={styles.actionButtonText}>Retry Failed</ThemedText>
              </TouchableOpacity>
            )}
            {stats.completed > 0 && (
              <TouchableOpacity
                style={[styles.actionButton, styles.clearButton]}
                onPress={() => uploadManager.clearCompleted()}>
                <ThemedText style={styles.actionButtonText}>Clear Completed</ThemedText>
              </TouchableOpacity>
            )}
          </View>
        )}

        {/* Upload Queue */}
        {tasks.length > 0 ? (
          <View style={styles.queueContainer}>
            <ThemedText type="subtitle" style={styles.queueTitle}>
              Upload Queue
            </ThemedText>
            {tasks.map((task) => (
              <UploadTaskItem key={task.id} task={task} />
            ))}
          </View>
        ) : (
          <View style={styles.emptyState}>
            <IconSymbol name="paperplane.fill" size={64} color="#ccc" />
            <ThemedText style={styles.emptyText}>No uploads yet</ThemedText>
            <ThemedText style={styles.emptySubtext}>
              Select images to start uploading
            </ThemedText>
          </View>
        )}
      </ScrollView>
    </ThemedView>
  );
}

// Upload Task Item Component
function UploadTaskItem({ task }: { task: UploadTask }) {
  const getStatusColor = () => {
    switch (task.status) {
      case 'completed':
        return '#4CAF50';
      case 'failed':
        return '#F44336';
      case 'uploading':
        return '#2196F3';
      default:
        return '#FFA726';
    }
  };

  const formatFileSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  return (
    <View style={styles.taskItem}>
      <View style={styles.taskHeader}>
        <ThemedText style={styles.taskFileName} numberOfLines={1}>
          {task.fileName}
        </ThemedText>
        <View style={[styles.statusBadge, { backgroundColor: getStatusColor() }]}>
          <ThemedText style={styles.statusText}>{task.status}</ThemedText>
        </View>
      </View>

      <View style={styles.taskDetails}>
        <ThemedText style={styles.taskInfo}>{formatFileSize(task.fileSize)}</ThemedText>
        {task.status === 'uploading' && (
          <ThemedText style={styles.taskInfo}>{task.progress.toFixed(0)}%</ThemedText>
        )}
      </View>

      {task.status === 'uploading' && (
        <View style={styles.progressBar}>
          <View style={[styles.progressFill, { width: `${task.progress}%` }]} />
        </View>
      )}

      {task.error && <ThemedText style={styles.errorText}>{task.error}</ThemedText>}

      {task.status === 'failed' && (
        <TouchableOpacity
          style={styles.retryTaskButton}
          onPress={() => uploadManager.retryTask(task.id)}>
          <ThemedText style={styles.retryTaskButtonText}>Retry</ThemedText>
        </TouchableOpacity>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 20,
    paddingBottom: 40,
  },
  header: {
    marginBottom: 20,
    marginTop: 20,
  },
  title: {
      paddingTop: 10,
  },
  subtitle: {
    opacity: 0.7,
    fontSize: 16,
  },
  selectButton: {
    backgroundColor: '#2196F3',
    borderRadius: 12,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
    marginBottom: 24,
  },
  selectButtonDisabled: {
    opacity: 0.6,
  },
  selectButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    backgroundColor: 'rgba(33, 150, 243, 0.1)',
    borderRadius: 12,
    padding: 16,
    marginBottom: 24,
  },
  statItem: {
    alignItems: 'center',
  },
  statNumber: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  statUploading: {
    color: '#2196F3',
  },
  statCompleted: {
    color: '#4CAF50',
  },
  statFailed: {
    color: '#F44336',
  },
  statLabel: {
    fontSize: 12,
    opacity: 0.7,
  },
  actionButtons: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 24,
  },
  actionButton: {
    flex: 1,
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  retryButton: {
    backgroundColor: '#FF9800',
  },
  clearButton: {
    backgroundColor: '#9E9E9E',
  },
  actionButtonText: {
    color: '#fff',
    fontWeight: '600',
  },
  queueContainer: {
    gap: 12,
  },
  queueTitle: {
    marginBottom: 8,
  },
  taskItem: {
    backgroundColor: 'rgba(0, 0, 0, 0.05)',
    borderRadius: 8,
    padding: 12,
    gap: 8,
  },
  taskHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 12,
  },
  taskFileName: {
    flex: 1,
    fontSize: 14,
    fontWeight: '500',
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  statusText: {
    color: '#fff',
    fontSize: 10,
    fontWeight: '600',
    textTransform: 'uppercase',
  },
  taskDetails: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  taskInfo: {
    fontSize: 12,
    opacity: 0.7,
  },
  progressBar: {
    height: 4,
    backgroundColor: 'rgba(0, 0, 0, 0.1)',
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#2196F3',
  },
  errorText: {
    fontSize: 12,
    color: '#F44336',
  },
  retryTaskButton: {
    alignSelf: 'flex-start',
    backgroundColor: '#FF9800',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
  },
  retryTaskButtonText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
    gap: 12,
  },
  emptyText: {
    fontSize: 18,
    fontWeight: '600',
    opacity: 0.5,
  },
  emptySubtext: {
    fontSize: 14,
    opacity: 0.4,
  },
});