#!/bin/bash
set -e
CHROOT=/home/jeryz/debian12
OUTPUT=/mnt/c/Users/jeryz/Desktop/fnllama/llama-cpp-fnnas/app/bin/x64

# mount
mount --bind /dev $CHROOT/dev 2>/dev/null || true
mount --bind /proc $CHROOT/proc 2>/dev/null || true
mount --bind /sys $CHROOT/sys 2>/dev/null || true
mkdir -p $CHROOT/output
mount --bind $OUTPUT $CHROOT/output 2>/dev/null || true

# patch
cat > $CHROOT/tmp/patch.sh << 'PATCHSCRIPT'
cd /tmp/llama.cpp
git checkout -- ggml/src/ggml-vulkan/ggml-vulkan.cpp
patch -p1 << 'EOF'
--- a/ggml/src/ggml-vulkan/ggml-vulkan.cpp
+++ b/ggml/src/ggml-vulkan/ggml-vulkan.cpp
@@ -7122,18 +7122,25 @@
     if (debug_utils_ext) {
         extensions.push_back("VK_EXT_debug_utils");
     }
+#if VK_HEADER_VERSION >= 260
     VkBool32 enable_best_practice = layer_settings;
     std::vector<vk::LayerSettingEXT> settings = {
         {
             "VK_LAYER_KHRONOS_validation",
             "validate_best_practices",
             vk::LayerSettingTypeEXT::eBool32,
             1,
             &enable_best_practice
         },
     };
     vk::LayerSettingsCreateInfoEXT layer_setting_info(settings);
     vk::InstanceCreateInfo instance_create_info(vk::InstanceCreateFlags{}, &app_info, layers, extensions, &layer_setting_info);
+#else
+    (void)layer_settings;
+    vk::InstanceCreateInfo instance_create_info(vk::InstanceCreateFlags{}, &app_info, layers, extensions);
+#endif
 #ifdef __APPLE__
     if (portability_enumeration_ext) {
         instance_create_info.flags |= vk::InstanceCreateFlagBits::eEnumeratePortabilityKHR;
EOF
echo "patch OK"
PATCHSCRIPT

chroot $CHROOT bash /tmp/patch.sh

# build
cat > $CHROOT/tmp/build.sh << 'BUILDSCRIPT'
cd /tmp/llama.cpp/build
cmake --build . --config Release -j$(nproc)
rm -rf /output/*
cp bin/* /output/
echo "DONE files: $(ls /output/ | wc -l)"
ls -lh /output/libggml-vulkan.so
BUILDSCRIPT

chroot $CHROOT bash /tmp/build.sh
