class FeatureFlags {
  static const bool enableBranchManagement = false;
  static const bool enableDesignationLevels = false;

  /// Central feature flags to temporarily disable document & image uploads
  static const bool enableDocumentUpload = false;
  static const bool enableImageUpload = false;

  /// Dev Mode: Enable instant verification bypass & dev login features
  static const bool enableDevModeBypass = true;
}
