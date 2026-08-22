// SPDX-License-Identifier: GPL-3.0-or-later

#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string>
#include <system_error>
#include <vector>

namespace fs = std::filesystem;

struct Finding {
    fs::path path;
    fs::path raw_target;
};

int main(int argc, char* argv[]) {
    std::vector<std::string> args(argv, argv + argc);
    // args[0] = 実行ファイル名
    // args[1]... = 起動時引数

    // 引数の数をチェックし、dotfiles_path を決定する
    fs::path dotfiles_path;
    if(args.size() == 1) {
        // default path("$HOME/dotfiles")
        // ~ は std::filesystem が展開してくれるものではない。
        // そのため、std::getenv("HOME")を使用する。
        const char* home = std::getenv("HOME");
        if(home == nullptr || *home == '\0') {
            std::cerr << "Error: HOME environment variable is not set.\n";
            return 2;
        }

        dotfiles_path = fs::path(home) / "dotfiles";
    } else if(args.size() == 2) {
        dotfiles_path = args[1];
    } else {
        std::cerr << "Usage: " << args[0] << " [path]\n";
        return 2;
    }

    // scan root の status を取得
    std::error_code ec;
    auto status = fs::status(dotfiles_path, ec);
    if(ec) {
        std::cerr << "ec.value(): " << ec.value() << '\n';
        std::cerr << "ec.message(): " << ec.message() << '\n';
        return 2;
    }

    // PATHとdirectoryのチェック
    if(!fs::exists(status)) {
        std::cerr << "Error: Path does not exist: " << dotfiles_path << '\n';
        return 2;
    }

    if(!fs::is_directory(status)) {
        std::cerr << "Error: Path is not a directory: " << dotfiles_path << '\n';
        return 2;
    }

    // scan root 以下を再帰走査する
    fs::recursive_directory_iterator it(dotfiles_path, ec);
    fs::recursive_directory_iterator end;

    if(ec) {
        std::cerr << "ec.value(): " << ec.value() << '\n';
        std::cerr << "ec.message(): " << ec.message() << '\n';
        return 2;
    }
    std::vector<Finding> findings;
    while(it != end) {
        // entry 自身の状態を取得する。
        // status() ではなく symlink_status() なので、
        // symbolic link の target を follow しない。リンク自身の状態を取得する。
        auto entry_status = it->symlink_status(ec);

        if(ec) {
            std::cerr << "ec.value(): " << ec.value() << '\n';
            std::cerr << "ec.message(): " << ec.message() << '\n';
            return 2;
        }

        // symlink の場合だけtargetを確認する。
        // regular file / directory は正常なので、そのまま無視する。
        if(fs::is_symlink(entry_status)) {
            // 現在entryのtargetをfollowするstatusを取得。リンク先を確認する。
            auto target_status = it->status(ec);
            // target statusのtypeを見る
            if(target_status.type() == fs::file_type::not_found) {
                // broken symlink の場合
                ec.clear();
                // read_symlink() でraw targetを取る
                auto raw_target = fs::read_symlink(it->path(), ec);
                if(ec) {
                    // read_symlink 自体に失敗
                    std::cerr << "file system error: " << '\n';
                    std::cerr << "ec.value(): " << ec.value() << '\n';
                    std::cerr << "ec.message(): " << ec.message() << '\n';
                    return 2;
                }

                findings.push_back({it->path(), raw_target});
            } else if(ec) {
                std::cerr << "file system error: " << '\n';
                std::cerr << "ec.value(): " << ec.value() << '\n';
                std::cerr << "ec.message(): " << ec.message() << '\n';
                return 2;
            }
        }


        // 次のentryへ進む
        it.increment(ec);

        if(ec) {
            std::cerr << "ec.value(): " << ec.value() << '\n';
            std::cerr << "ec.message(): " << ec.message() << '\n';
            return 2;
        }
    }

    // broken symlink の一覧を表示する
    if(!findings.empty()) {
        std::sort(findings.begin(), findings.end(), [](const Finding& a, const Finding& b) {
            return a.path < b.path;
        });

        for(const auto& finding : findings) {
            std::cout << "BROKEN: "
                      << finding.path.lexically_relative(dotfiles_path)
                      << " -> "
                      << finding.raw_target
                      << '\n';
        }

        // 1件でもbroken symlinkが見つかったら1を返す
        return 1;
    }

    std::cout << "OK: no broken symlinks found.\n";

    // Broken symlinkが見つからなかった場合は正常終了
    return 0;
}
