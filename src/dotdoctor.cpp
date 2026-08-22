// SPDX-License-Identifier: GPL-3.0-or-later

#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <system_error>
#include <vector>

namespace fs = std::filesystem;

constexpr int kExitClean = 0;
constexpr int kExitFindings = 1;
constexpr int kExitError = 2;

struct Finding {
    fs::path path;
    fs::path raw_target;
};

int report_filesystem_error(const char* action,
                            const fs::path& path,
                            const std::error_code& ec) {
    std::cerr << "Error: " << action << ": " << path << ": " << ec.message() << '\n';
    return kExitError;
}

int scan_broken_symlinks(const fs::path& scan_root, std::vector<Finding>& findings) {
    std::error_code ec;
    fs::recursive_directory_iterator it(scan_root, ec);
    fs::recursive_directory_iterator end;

    if(ec) {
        return report_filesystem_error("failed to open scan root", scan_root, ec);
    }

    while(it != end) {
        const auto entry_status = it->symlink_status(ec);
        if(ec) {
            return report_filesystem_error("failed to inspect entry", it->path(), ec);
        }

        if(fs::is_symlink(entry_status)) {
            const auto target_status = it->status(ec);

            // A broken symlink can produce both file_type::not_found and ENOENT.
            // Classify not_found before treating ec as a scan error.
            if(target_status.type() == fs::file_type::not_found) {
                ec.clear();

                const auto raw_target = fs::read_symlink(it->path(), ec);
                if(ec) {
                    return report_filesystem_error("failed to read symlink", it->path(), ec);
                }

                findings.push_back({it->path(), raw_target});
            } else if(ec) {
                return report_filesystem_error(
                    "failed to inspect symlink target", it->path(), ec);
            }
        }

        // recursive_directory_iterator does not follow directory symlinks
        // unless follow_directory_symlink is explicitly requested.
        it.increment(ec);
        if(ec) {
            return report_filesystem_error("failed while traversing", scan_root, ec);
        }
    }

    return kExitClean;
}

int main(int argc, char* argv[]) {
    if(argc > 2) {
        std::cerr << "Usage: " << argv[0] << " [path]\n";
        return kExitError;
    }

    fs::path scan_root;

    if(argc == 2) {
        scan_root = argv[1];
    } else {
        const char* home = std::getenv("HOME");
        if(home == nullptr || *home == '\0') {
            std::cerr << "Error: HOME environment variable is not set.\n";
            return kExitError;
        }

        // std::filesystem does not expand '~'.
        scan_root = fs::path(home) / "dotfiles";
    }

    std::error_code ec;
    const auto root_status = fs::status(scan_root, ec);

    if(root_status.type() == fs::file_type::not_found) {
        std::cerr << "Error: Path does not exist: " << scan_root << '\n';
        return kExitError;
    }

    if(ec) {
        return report_filesystem_error("failed to inspect scan root", scan_root, ec);
    }

    if(!fs::is_directory(root_status)) {
        std::cerr << "Error: Path is not a directory: " << scan_root << '\n';
        return kExitError;
    }

    std::vector<Finding> findings;

    const int scan_result = scan_broken_symlinks(scan_root, findings);
    if(scan_result != kExitClean) {
        return scan_result;
    }

    if(findings.empty()) {
        std::cout << "OK: no broken symlinks found.\n";
        return kExitClean;
    }

    std::sort(findings.begin(), findings.end(), [](const Finding& lhs, const Finding& rhs) {
        return lhs.path < rhs.path;
    });

    for(const auto& finding : findings) {
        std::cout << "BROKEN: "
                  << finding.path.lexically_relative(scan_root)
                  << " -> "
                  << finding.raw_target
                  << '\n';
    }

    return kExitFindings;
}
