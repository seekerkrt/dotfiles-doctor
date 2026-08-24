// SPDX-License-Identifier: GPL-3.0-or-later

#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string>
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
            // A symlink loop reports ELOOP instead, but is equally unresolvable.
            // Classify both before treating ec as a scan error.
            if(target_status.type() == fs::file_type::not_found || ec == std::errc::too_many_symbolic_link_levels) {
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

void print_help() {
    std::cout << "Usage: dotdoc [OPTIONS] [PATH]\n"
              << "\n"
              << "Scan a directory tree for broken symbolic links.\n"
              << "\n"
              << "Without PATH, $HOME/dotfiles is scanned.\n"
              << "With PATH, the specified directory tree is scanned.\n"
              << "\n"
              << "Options:\n"
              << "  -h, --help    Show this help and exit\n"
              << "  --version     Show version information and exit\n"
              << "\n"
              << "Exit status:\n"
              << "  0  Scan completed with no findings\n"
              << "  1  Scan completed with findings\n"
              << "  2  Invocation or filesystem error\n"
              << "\n"
              << "Exit status 1 indicates diagnostic findings, not program failure.\n";
}

void print_version() {
    std::cout << "dotdoc " << DOTDOC_VERSION << '\n';
}

int main(int argc, char* argv[]) {
    std::vector<std::string> args(argv + 1, argv + argc);

    fs::path scan_root;
    if(args.size() >= 2) {
        std::cerr << "Usage: dotdoc [OPTIONS] [PATH]\n";
        return kExitError;
    }
    if(args.size() == 1) {
        if(args[0] == "-h" || args[0] == "--help") {
            print_help();
            return kExitClean;
        }
        if(args[0] == "--version") {
            print_version();
            return kExitClean;
        }

        // If a path is provided, use it as the scan root.
        scan_root = args[0];
    } else if(args.empty()) {
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

    std::cout << "Found " << findings.size()
              << " broken symlink"
              << (findings.size() == 1 ? "" : "s")
              << ".\n";

    return kExitFindings;
}
