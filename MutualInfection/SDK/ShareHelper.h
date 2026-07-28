//
//  ShareHelper.h
//  MutualInfection
//
//  Created by Law on 2025/9/4.
//

#ifndef ShareHelper_h
#define ShareHelper_h

#include <vector>
#include <cstdint>

// EA解码结果结构体
struct UnPackagedEA {
    unsigned int value;
    unsigned int offset;
};

class ShareHelper {
public:
    /**
     * 对整数值进行EA编码并返回vector<uint8_t>
     * @param1 value 需要编码的整数值
     * @param2 编码后的字节向量
     */
    static void addEA(int value, std::vector<uint8_t> &EAPacket);

    /**
     * 从字节向量中解码EA编码的值
     * @param data 包含EA编码数据的字节向量
     * @param begin 开始解码的位置
     * @return 解码结果结构体
     */
    static UnPackagedEA removeEA(const std::vector<uint8_t>& data, unsigned int begin);
};

#endif /* ShareHelper_h */