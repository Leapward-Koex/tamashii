#pragma once

// Compatibility surface for the sole ATL API used by
// flutter_local_notifications_windows 3.1.1. Keep this intentionally limited:
// it converts a UTF-16 Windows string to the requested Windows code page.

#include <windows.h>

#include <stdexcept>
#include <string>
#include <vector>

class CW2A final : public std::string {
 public:
  explicit CW2A(const wchar_t* value, unsigned int code_page = CP_ACP)
      : std::string(convert(value, code_page)) {}

 private:
  static std::string convert(const wchar_t* value, unsigned int code_page) {
    if (value == nullptr) {
      return {};
    }

    const int size =
        WideCharToMultiByte(code_page, 0, value, -1, nullptr, 0, nullptr, nullptr);
    if (size <= 0) {
      throw std::runtime_error("WideCharToMultiByte failed");
    }

    std::vector<char> buffer(static_cast<size_t>(size));
    if (WideCharToMultiByte(code_page, 0, value, -1, buffer.data(), size,
                            nullptr, nullptr) <= 0) {
      throw std::runtime_error("WideCharToMultiByte failed");
    }

    return {buffer.data(), static_cast<size_t>(size - 1)};
  }
};
