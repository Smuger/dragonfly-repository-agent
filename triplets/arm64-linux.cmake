set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# Release-only: mirrors x64-linux.cmake so local Apple Silicon builds match CI's
# release-only behaviour (skips the failing azure-storage-common-cpp debug build).
set(VCPKG_BUILD_TYPE release)
