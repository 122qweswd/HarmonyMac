//
//  ShareHelper.mm
//  MutualInfection
//
//  Created by Law on 2025/9/4.
//

#include "ShareHelper.h"
#include <vector>

static const unsigned int LENGTH_FIELD_EA_MAXIMUM = 4;
static const uint8_t EA = 0x80;
static const uint8_t EA_OFFSET = 7;

void ShareHelper::addEA(int value, std::vector<uint8_t> &EAPacket) {
    EAPacket.clear();
    std::vector<uint8_t> innerVector(LENGTH_FIELD_EA_MAXIMUM);
    unsigned int i;
    int tempValue = value;
    
    for (i = 0; i < LENGTH_FIELD_EA_MAXIMUM; i++) {
        innerVector[i] = (((unsigned int)tempValue) & (~EA));
        tempValue = (((unsigned int)tempValue) >> EA_OFFSET);
        if (tempValue == 0) {
            innerVector[i] = (innerVector[i] | EA);
            i += 1;
            break;
        }
    }
    EAPacket.insert(EAPacket.end(), innerVector.begin(), innerVector.begin() + i);
}

UnPackagedEA ShareHelper::removeEA(const std::vector<uint8_t>& data, unsigned int begin) {
    UnPackagedEA outData = {0, begin};
    
    // 检查边界条件
    if (data.empty() || begin >= data.size()) {
        return outData;
    }
    
    unsigned int end = begin + LENGTH_FIELD_EA_MAXIMUM;
    if (end > data.size()) {
        end = (unsigned int)data.size();
    }
    
    unsigned int offset = begin;
    unsigned int value = 0;
    
    for (; offset < end; offset++) {
        // 避免未定义行为，先转换为unsigned int
        uint8_t byte = data[offset];
        value |= (byte & (~EA)) << ((offset - begin) * EA_OFFSET);
        if ((byte & EA) == EA) {
            offset += 1;
            break;
        }
    }
    
    outData.value = value;
    outData.offset = offset;
    
    return outData;
}
/* 使用示例 */
/*
EA编码
std::vector<uint8_t> encodedData = ShareHelper::addEA(12345);

EA解码

UnPackagedEA result = ShareHelper::removeEA(encodedData, 0);
*/