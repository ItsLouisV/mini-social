#!/bin/bash

# 1. Tạo file .env từ các biến môi trường cấu hình trên Vercel
echo "SUPABASE_URL=$SUPABASE_URL" > .env
echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
echo "LIVEKIT_URL=$LIVEKIT_URL" >> .env

# Nhân bản file .env cho các môi trường dev, staging, production để tránh lỗi đóng gói Asset của Flutter
cp .env .env.development
cp .env .env.staging
cp .env .env.production


# 2. Clone Flutter SDK bản stable trực tiếp từ GitHub
git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter-sdk

# 3. Thêm Flutter vào biến PATH tạm thời để chạy lệnh
export PATH="$PATH:$(pwd)/flutter-sdk/bin"

# 4. Tải các thư viện và tạo code Riverpod tự động
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 5. Biên dịch Flutter Web
flutter build web --release
