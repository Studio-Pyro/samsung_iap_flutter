# The Samsung IAP 6.5.2 AAR ships no consumer rules. These are its AIDL
# classes, which talk to Galaxy Store across processes, so R8 must leave them
# whole.
-keep class com.samsung.android.iap.** { *; }
