import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeatureFlagsProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _aiAnalyticsEngine = true;
  bool _geofenceVerificationService = true;
  bool _multiFactorAuthRequirement = false;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  FeatureFlagsProvider() {
    fetchFeatureFlags();
  }

  // Getters
  bool get aiAnalyticsEngine => _aiAnalyticsEngine;
  bool get geofenceVerificationService => _geofenceVerificationService;
  bool get multiFactorAuthRequirement => _multiFactorAuthRequirement;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  DocumentReference<Map<String, dynamic>> get _featuresDoc =>
      _firestore.collection('system_config').doc('features');

  /// Fetches feature flag configurations from Cloud Firestore
  Future<void> fetchFeatureFlags() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final doc = await _featuresDoc.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _aiAnalyticsEngine = data['aiAnalyticsEngine'] ?? true;
        _geofenceVerificationService = data['geofenceVerificationService'] ?? true;
        _multiFactorAuthRequirement = data['multiFactorAuthRequirement'] ?? false;
      } else {
        // Initialize default configuration document in Firestore if not existing
        await _featuresDoc.set({
          'aiAnalyticsEngine': true,
          'geofenceVerificationService': true,
          'multiFactorAuthRequirement': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      _errorMessage = "Failed to load feature flags: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Helper to update a feature toggle in Firestore with duplicate request protection
  Future<bool> _toggleFeature(String key, bool newValue, Function(bool) updateLocalState) async {
    if (_isSaving) return false; // Prevent concurrent duplicate saves

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    // Optimistically update local UI state immediately
    updateLocalState(newValue);
    notifyListeners();

    try {
      await _featuresDoc.set({
        key: newValue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Revert local state on error
      updateLocalState(!newValue);
      _errorMessage = "Failed to save feature setting: ${e.toString()}";
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setAiAnalyticsEngine(bool value) async {
    return await _toggleFeature('aiAnalyticsEngine', value, (val) => _aiAnalyticsEngine = val);
  }

  Future<bool> setGeofenceVerificationService(bool value) async {
    return await _toggleFeature('geofenceVerificationService', value, (val) => _geofenceVerificationService = val);
  }

  Future<bool> setMultiFactorAuthRequirement(bool value) async {
    return await _toggleFeature('multiFactorAuthRequirement', value, (val) => _multiFactorAuthRequirement = val);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
