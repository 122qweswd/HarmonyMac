//
//  StringParse.h
//  MutualInfection
//
//  Created by Law on 2025/10/20.
//

#include <iostream>
#include <string>
#include <sstream>
#include <unordered_map>
#include <algorithm>

class StringParser {
public:
    // 解析整个字符串到map中
    static std::unordered_map<std::string, std::string> parse_to_map(const std::string& input) {
        std::unordered_map<std::string, std::string> result;
        std::stringstream ss(input);
        std::string token;

        while (std::getline(ss, token, ',')) {
            size_t colon_pos = token.find(':');
            if (colon_pos != std::string::npos) {
                std::string key = trim(token.substr(0, colon_pos));
                std::string value = trim(token.substr(colon_pos + 1));
                result[key] = value;
            }
        }

        return result;
    }

    // 获取特定字段的值
    static std::string get_field_value(const std::string& input, const std::string& field_name) {
        auto field_map = parse_to_map(input);
        auto it = field_map.find(field_name);
        if (it != field_map.end()) {
            return it->second;
        }
        return ""; // 或者抛出异常
    }

    // 获取特定字段的整数值
    static int get_field_int_value(const std::string& input, const std::string& field_name, int default_value = -1) {
        std::string value_str = get_field_value(input, field_name);
        if (!value_str.empty()) {
            try {
                return std::stoi(value_str);
            } catch (const std::exception& e) {
                std::cerr << "Error parsing " << field_name << " value: " << e.what() << std::endl;
                return default_value;
            }
        }
        return default_value;
    }

private:
    // 去除字符串两端的空白字符
    static std::string trim(const std::string& str) {
        size_t start = str.find_first_not_of(" \t\n\r");
        size_t end = str.find_last_not_of(" \t\n\r");

        if (start == std::string::npos) {
            return "";
        }

        return str.substr(start, end - start + 1);
    }
};
