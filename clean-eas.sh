#!/bin/bash

# Clean EAS metadata script
# Run this if you need to start fresh with EAS setup

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Cleaning EAS metadata...${NC}"

cd frontend

# Remove EAS cache and metadata
if [ -d ".expo" ]; then
    rm -rf .expo
    echo -e "${GREEN}✓ Removed .expo directory${NC}"
fi

# Reset app.json to template state (removes projectId)
cat > app.json << 'EOF'
{
  "expo": {
    "name": "S3 Mobile Storage",
    "slug": "s3-mobile-storage",
    "version": "1.0.0",
    "main": "expo-router/entry",
    "android": {
      "package": "com.yourusername.s3mobilestorage",
      "permissions": [
        "android.permission.INTERNET",
        "android.permission.READ_MEDIA_IMAGES",
        "android.permission.WAKE_LOCK",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.CAMERA",
        "android.permission.RECORD_AUDIO"
      ]
    },
    "plugins": [
      [
        "expo-image-picker",
        {
          "photosPermission": "Allow $(PRODUCT_NAME) to access your photos.",
          "cameraPermission": "Allow $(PRODUCT_NAME) to use your camera."
        }
      ]
    ]
  }
}
EOF

echo -e "${GREEN}✓ Reset app.json to template state${NC}"

cd ..

echo ""
echo -e "${GREEN}EAS metadata cleaned!${NC}"
echo ""
echo -e "${YELLOW}You can now run ./setup.sh again${NC}"