import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();

  factory SyncManager() => _instance;
  SyncManager._internal();

  final Map<String, dynamic> _pendingUpdates = {};
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Queue an update for batching
  void queueUpdate(String key, dynamic value) {
    _pendingUpdates[key] = value;
    debugPrint('📦 SyncManager: Queued "$key" (pending: ${_pendingUpdates.length})');
  }

  /// Batch queue multiple updates at once
  void queueBatch(Map<String, dynamic> updates) {
    _pendingUpdates.addAll(updates);
    debugPrint('📦 SyncManager: Queued batch of ${updates.length} updates');
  }

  /// Check if sync is needed based on time elapsed
  bool shouldSync() {
    if (_pendingUpdates.isEmpty) {
      return false;
    }

    final now = DateTime.now();
    if (_lastSyncTime == null) return true;

    // Sync if 2 minutes have passed
    final timeSinceLastSync = now.difference(_lastSyncTime!).inSeconds;
    return timeSinceLastSync > 120; // 2 minutes
  }

  /// Force sync all pending data to Firebase
  Future<bool> syncNow({bool forceWrite = false}) async {
    if (_pendingUpdates.isEmpty) {
      debugPrint('✅ SyncManager: No pending updates to sync');
      return true; // Nothing to sync, so success
    }

    // Skip if not enough time has passed (unless forced)
    if (!forceWrite && !shouldSync()) {
      debugPrint('⏭️  SyncManager: Skipping sync (last sync was recent)');
      return true; // Not time yet
    }

    if (_isSyncing) {
      debugPrint('⏳ SyncManager: Sync already in progress');
      return false;
    }

    _isSyncing = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ SyncManager: No user logged in');
        return false;
      }

      debugPrint('🔄 SyncManager: Syncing ${_pendingUpdates.length} updates...');

      // 🟢 Add timeout to prevent hanging on network issues
      final result = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        ..._pendingUpdates,
        'lastSyncedAt': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Firebase sync timed out after 10 seconds');
        },
      );

      _lastSyncTime = DateTime.now();
      final syncedCount = _pendingUpdates.length;
      _pendingUpdates.clear();

      debugPrint('✅ SyncManager: Successfully synced $syncedCount updates to Firebase');
      return true;
    } on FirebaseException catch (e) {
      debugPrint('❌ SyncManager: Firebase error: ${e.code} - ${e.message}');
      debugPrint('Stack: ${e.stackTrace}');
      // Keep updates in queue for next retry
      return false;
    } on SocketException catch (e) {
      debugPrint('❌ SyncManager: Network error: ${e.message}');
      // Keep updates in queue for next retry
      return false;
    } on TimeoutException catch (e) {
      debugPrint('❌ SyncManager: $e');
      // Keep updates in queue for next retry
      return false;
    } catch (e, stack) {
      debugPrint('❌ SyncManager: Unknown error: $e');
      debugPrint('Stack Trace: $stack');
      // Keep updates in queue for next retry
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  int getPendingCount() => _pendingUpdates.length;
  Map<String, dynamic> getPendingUpdates() => Map.from(_pendingUpdates);
  void clearPending() {
    _pendingUpdates.clear();
    debugPrint('🗑️  SyncManager: Cleared pending updates');
  }
  void resetSyncTimer() {
    _lastSyncTime = null;
    debugPrint('🔄 SyncManager: Reset sync timer');
  }
}
