# Defensive. The Samsung IAP 6.5.2 AAR ships no consumer rules. The SDK uses
# no reflection and its binder descriptors are string literals, so renaming is
# probably harmless. A minified release purchase on a device is the real check.
-keep class com.samsung.android.iap.** { *; }
