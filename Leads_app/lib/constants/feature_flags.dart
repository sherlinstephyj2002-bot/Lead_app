class FeatureFlags {
  static const bool enableBranchManagement = false;
  static const bool enableDesignationLevels = false;

  /// Central feature flag for document attachments
  static const bool enableDocumentUpload = false;

  /// Dev Mode: Enable instant verification bypass & dev login features
  static const bool enableDevModeBypass = true;
}
