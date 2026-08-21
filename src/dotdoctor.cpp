// SPDX-License-Identifier: GPL-3.0-or-later

#include <iostream>
#include <vector>
#include <string>

int main(int argc, char* argv[]) {
    std::vector<std::string> args(argv, argv + argc);
    // args[0] = 実行ファイル名
    // args[1]... = 起動時引数
    return 0;
}
