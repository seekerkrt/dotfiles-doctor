// SPDX-License-Identifier: GPL-3.0-or-later

#include <algorithm>
#include <cstddef>
#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string>
#include <system_error>
#include <vector>

namespace fs = std::filesystem;

namespace {

constexpr int kExitClean = 0;
constexpr int kExitFindings = 1;
constexpr int kExitError = 2;

enum class DiagnosticKind {
    kAbsolute,
    kBroken,
};

struct Finding {
    DiagnosticKind kind;
    fs::path path;
    fs::path raw_target;
};

int report_filesystem_error(
    const char* action,
    const fs::path& path,
    const std::error_code& ec);

int scan_diagnostic_findings(
    const fs::path& scan_root,
    const std::vector<fs::path>& exclude_paths,
    std::vector<Finding>& findings);

void print_help();
void print_version();

} // namespace

int main(int argc, char* argv[]) {
    const std::vector<std::string> args(argv + 1, argv + argc);
    std::vector<fs::path> exclude_paths;
    fs::path scan_root;
    bool scan_root_provided = false;

    for(std::size_t i = 0; i < args.size(); ++i) {
        const auto& arg = args[i];
        if(arg == "-h" || arg == "--help") {
            print_help();
            return kExitClean;
        } else if(arg == "--version") {
            print_version();
            return kExitClean;
        } else if(arg == "--exclude") {
            if(i + 1 < args.size()) {
                exclude_paths.push_back(args[i + 1]);
                ++i;
                continue;
            } else {
                std::cerr << "Error: --exclude option requires a path argument.\n";
                return kExitError;
            }
        } else if(scan_root_provided) {
            std::cerr << "Error: Only one PATH argument is allowed.\n";
            return kExitError;
        } else {
            scan_root = arg;
            scan_root_provided = true;
            continue;
        }
    }

    if(!scan_root_provided) {
        // std::filesystem does not expand '~'.
        const char* home = std::getenv("HOME");
        if(home == nullptr || *home == '\0') {
            std::cerr << "Error: HOME environment variable is not set.\n";
            return kExitError;
        }
        scan_root = fs::path(home) / "dotfiles";
    }

    bool scan_root_excluded = false;
    std::vector<fs::path> normalized_exclude_paths;

    // Exclude paths are interpreted lexically relative to the scan root.
    for(const auto& exclude : exclude_paths) {
        if(exclude.is_absolute()) {
            std::cerr << "Error: Exclude path must be relative to scan root: " << exclude << '\n';
            return kExitError;
        }

        const auto normalized_exclude = exclude.lexically_normal();

        if(normalized_exclude.empty()) {
            std::cerr << "Error: Exclude path is empty: " << exclude << '\n';
            return kExitError;
        }
        // "." excludes the scan root itself, but the root is still validated first.
        if(normalized_exclude == fs::path(".")) {
            scan_root_excluded = true;
            continue;
        }
        if(normalized_exclude.begin()->string() == "..") {
            std::cerr << "Error: Exclude path escapes scan root: " << exclude << '\n';
            return kExitError;
        }

        normalized_exclude_paths.push_back(fs::path(scan_root / normalized_exclude).lexically_normal());
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
    int scan_result = kExitClean;

    if(!scan_root_excluded) {
        scan_result = scan_diagnostic_findings(
            scan_root,
            normalized_exclude_paths,
            findings);
    }

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

namespace {

int report_filesystem_error(const char* action,
                            const fs::path& path,
                            const std::error_code& ec) {
    std::cerr << "Error: " << action << ": " << path << ": " << ec.message() << '\n';
    return kExitError;
}

int scan_diagnostic_findings(const fs::path& scan_root, const std::vector<fs::path>& exclude_paths, std::vector<Finding>& findings) {
    std::error_code ec;
    // Default iterator options intentionally do not follow directory symlinks.
    fs::recursive_directory_iterator it(scan_root, ec);
    fs::recursive_directory_iterator end;

    if(ec) {
        return report_filesystem_error("failed to open scan root", scan_root, ec);
    }

    while(it != end) {
        const auto current_path = it->path().lexically_normal();
        bool is_excluded = false;

        for(const auto& exclude : exclude_paths) {
            if(current_path == exclude) {
                is_excluded = true;
                it.disable_recursion_pending();
                break;
            }
        }

        if(is_excluded) {
            it.increment(ec);
            if(ec) {
                return report_filesystem_error("failed while traversing", scan_root, ec);
            }
            continue;
        }

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
              << "  --exclude PATH  Exclude PATH relative to the scan root; may be repeated\n"
              << "  -h, --help      Show this help and exit\n"
              << "  --version       Show version information and exit\n"
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

} // namespace
