#include <clocale>
#include <compare>
#include <iostream>
#include <string>
#include <string_view>

namespace nix {
std::strong_ordering compareVersions(std::string_view, std::string_view);
}

static_assert(sizeof(int) == 4, "This oracle is the inspected Linux int32 Nix profile");

std::string bytes(std::string_view hex) {
    auto digit = [](unsigned char b) { return b <= '9' ? b - '0' : b - 'a' + 10; };
    std::string result;
    result.reserve(hex.size() / 2);
    for (std::size_t i = 0; i < hex.size(); i += 2)
        result.push_back(static_cast<char>(digit(hex[i]) * 16 + digit(hex[i + 1])));
    return result;
}

void compare(std::string_view a, std::string_view b) {
    const auto left = bytes(a);
    const auto right = bytes(b);
    const auto order = nix::compareVersions(left, right);
    std::cout << (order < 0 ? -1 : order > 0 ? 1 : 0) << '\n';
}

int main(int argc, char **argv) {
    if (!std::setlocale(LC_ALL, "C")) return 2;
    if (argc == 3) {
        compare(argv[1], argv[2]);
    } else {
        std::string line;
        while (std::getline(std::cin, line)) {
            const auto split = line.find(' ');
            compare(std::string_view(line).substr(0, split), std::string_view(line).substr(split + 1));
        }
    }
}
