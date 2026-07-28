//
//  CIrcularBuffer.h
//  MutualInfection
//
//  Created by apple on 2025/9/29.
//

#ifndef CIRCULAR_BUFFER_H
#define CIRCULAR_BUFFER_H

#include <vector>
#include "Common.h"
#include "AuthChannel.h"

class CircularBuffer
{
public:
    void SetSize(uint32_t size);
    uint32_t GetSize() const;
    uint32_t GetCount() const;
    bool Put(const std::vector<uint8_t> &packet);
    bool Get(TdcPacketHead &hdr, std::vector<uint8_t> &packet);
    bool Get(TdcDataPacketHead &hdr, std::vector<uint8_t> &packet);
    void Clear();

private:
    std::vector<uint8_t> buffer;
    uint32_t rdIndex { 0 };
    uint32_t wrIndex { 0 };
    uint32_t maxSize { 0 };
};

#endif // CIRCULAR_BUFFER_H
