/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Backlight HAL for HUAWEI MateBook E 2019 (planck).
 */

#include <aidl/android/hardware/light/BnLights.h>
#include <android-base/file.h>
#include <android-base/logging.h>
#include <android-base/parseint.h>
#include <android-base/strings.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>

#include <dirent.h>

#include <algorithm>
#include <cerrno>
#include <cstring>
#include <string>
#include <vector>

namespace aidl::android::hardware::light {

namespace {

constexpr char kBacklightDir[] = "/sys/class/backlight";

std::string FindBacklight() {
    std::unique_ptr<DIR, decltype(&closedir)> dir(opendir(kBacklightDir), closedir);
    if (!dir) {
        PLOG(ERROR) << "Unable to open " << kBacklightDir;
        return "";
    }

    std::vector<std::string> names;
    while (dirent* entry = readdir(dir.get())) {
        std::string name(entry->d_name);
        if (name != "." && name != "..") {
            names.push_back(name);
        }
    }
    if (names.empty()) {
        LOG(ERROR) << "No backlight device found";
        return "";
    }

    std::sort(names.begin(), names.end());
    if (names.size() > 1) {
        LOG(WARNING) << names.size() << " backlights found, using " << names.front();
    }
    return std::string(kBacklightDir) + "/" + names.front();
}

int ReadInt(const std::string& path, int fallback) {
    std::string value;
    int parsed;
    if (!::android::base::ReadFileToString(path, &value) ||
        !::android::base::ParseInt(::android::base::Trim(value), &parsed)) {
        return fallback;
    }
    return parsed;
}

uint32_t ToBrightness(int32_t color) {
    const uint32_t c = static_cast<uint32_t>(color);
    return ((77 * ((c >> 16) & 0xff)) + (150 * ((c >> 8) & 0xff)) +
            (29 * (c & 0xff))) >> 8;
}

}  // namespace

class Lights final : public BnLights {
  public:
    Lights() : path_(FindBacklight()) {
        if (!path_.empty()) {
            max_brightness_ = ReadInt(path_ + "/max_brightness", 255);
            if (max_brightness_ <= 0) {
                max_brightness_ = 255;
            }
        }
    }

    ndk::ScopedAStatus setLightState(int32_t id, const HwLightState& state) override {
        if (id != kBacklightId || path_.empty()) {
            return ndk::ScopedAStatus::ok();
        }

        const int value = std::clamp(
                static_cast<int>((ToBrightness(state.color) * max_brightness_) / 255),
                0, max_brightness_);
        if (!::android::base::WriteStringToFile(std::to_string(value),
                                                path_ + "/brightness")) {
            PLOG(ERROR) << "Unable to write backlight brightness";
        }
        // LightsService does not handle failures from a backlight update.
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus getLights(std::vector<HwLight>* lights) override {
        lights->clear();
        if (!path_.empty()) {
            HwLight light;
            light.id = kBacklightId;
            light.ordinal = 0;
            light.type = LightType::BACKLIGHT;
            lights->push_back(light);
        }
        return ndk::ScopedAStatus::ok();
    }

  private:
    static constexpr int32_t kBacklightId = 0;
    const std::string path_;
    int max_brightness_ = 255;
};

}  // namespace aidl::android::hardware::light

int main() {
    ABinderProcess_setThreadPoolMaxThreadCount(0);
    auto service =
            ::ndk::SharedRefBase::make<aidl::android::hardware::light::Lights>();
    const std::string name = std::string(
            aidl::android::hardware::light::Lights::descriptor) + "/default";
    const binder_status_t status =
            AServiceManager_addService(service->asBinder().get(), name.c_str());
    if (status != STATUS_OK) {
        LOG(FATAL) << "Unable to register " << name << ": " << status;
    }
    ABinderProcess_joinThreadPool();
    return EXIT_FAILURE;
}

