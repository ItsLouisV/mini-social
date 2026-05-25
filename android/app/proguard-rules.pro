# 📌 WebRTC & LiveKit Obfuscation Prevention Rules

# Giữ lại toàn bộ lớp và phương thức của WebRTC (JNI native bridge)
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Giữ lại toàn bộ lớp và phương thức của LiveKit SDK
-keep class com.github.livekit.** { *; }
-keep class io.livekit.** { *; }
-dontwarn com.github.livekit.**
-dontwarn io.livekit.**
