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

enum class DiagnosticKind {
    kAbsolute, // symlink target is absolute
    kBroken, // symlink target is broken
};

struct Finding {
    DiagnosticKind kind;
    fs::path path;
    fs::path raw_target;
};

int report_filesystem_error(const char* action,
                            const fs::path& path,
                            const std::error_code& ec) {
    std::cerr << "Error: " << action << ": " << path << ": " << ec.message() << '\n';
    return kExitError;
}

int scan_diagnostic_findings(const fs::path& scan_root, std::vector<Finding>& findings) {
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
            std::error_code status_ec;
            const auto target_status = it->status(status_ec);

            std::error_code read_ec;
            const auto raw_target = fs::read_symlink(it->path(), read_ec);

            const bool is_broken = target_status.type() == fs::file_type::not_found || status_ec == std::errc::too_many_symbolic_link_levels;

            if(!is_broken && status_ec) {
                return report_filesystem_error("failed to inspect symlink target", it->path(), status_ec);
            }

            if(read_ec) {
                return report_filesystem_error("failed to read symlink", it->path(), read_ec);
            }

            if(is_broken) {
                findings.push_back({DiagnosticKind::kBroken, it->path(), raw_target});
            }

            if(raw_target.is_absolute()) {
                findings.push_back({DiagnosticKind::kAbsolute, it->path(), raw_target});
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
              << "Scan a directory tree for symbolic-link findings.\n"
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

    const int scan_result = scan_diagnostic_findings(scan_root, findings);
    if(scan_result != kExitClean) {
        return scan_result;
    }

    if(findings.empty()) {
        std::cout << "OK: no findings.\n";
        return kExitClean;
    }

    std::sort(findings.begin(), findings.end(), [](const Finding& lhs, const Finding& rhs) {
        if(lhs.path == rhs.path) {
            return lhs.kind == DiagnosticKind::kBroken && rhs.kind == DiagnosticKind::kAbsolute;
        }
        return lhs.path < rhs.path;
    });

    for(const auto& finding : findings) {
        switch(finding.kind) {
            case DiagnosticKind::kBroken:
                std::cout << "BROKEN: " << finding.path.lexically_relative(scan_root) << " -> " << finding.raw_target << '\n';
                break;
            case DiagnosticKind::kAbsolute:
                std::cout << "ABSOLUTE: " << finding.path.lexically_relative(scan_root) << " -> " << finding.raw_target << '\n';
                break;
        }
    }

    std::cout << "Found " << findings.size()
              << " finding"
              << (findings.size() == 1 ? "" : "s")
              << ".\n";

    return kExitFindings;
}
