# Keep Razorpay SDK classes
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Keep annotations used by Razorpay
-keep @interface proguard.annotation.Keep
-keep @interface proguard.annotation.KeepClassMembers
