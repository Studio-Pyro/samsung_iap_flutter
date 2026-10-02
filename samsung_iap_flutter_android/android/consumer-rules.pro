# Defensive. The Samsung IAP 6.5.2 AAR ships no consumer rules, so this keeps
# its AIDL classes as they are. No reflection was found in the SDK, and the
# binder descriptors are string literals, so renaming may well be harmless.
# The minified release purchase on a device is the real check.
-keep class com.samsung.android.iap.** { *; }
