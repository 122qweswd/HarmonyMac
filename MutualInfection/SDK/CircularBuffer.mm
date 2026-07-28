//
//  CIrcularBuffer.mm
//  MutualInfection
//
//  Created by apple on 2025/9/29.
//

#include "CircularBuffer.h"
#include "LogHelper.h"

void CircularBuffer::SetSize(uint32_t size)
{
    buffer.resize(size);
    maxSize = size;
}

uint32_t CircularBuffer::GetSize() const
{
    return maxSize;
}

uint32_t CircularBuffer::GetCount() const
{
    if (wrIndex < rdIndex) {
        return wrIndex + maxSize - rdIndex;
    }
    return wrIndex - rdIndex;
}

bool CircularBuffer::Put(const std::vector<uint8_t> &packet)
{
    uint32_t freeSpace = maxSize - GetCount();
    if (packet.size() > freeSpace) {
        LOG_ERROR_S("buffer overflow");
        return false;
    }

    uint32_t copyed = static_cast<uint32_t>(packet.size());
    auto pktBuffer = packet.data();
    if (wrIndex < rdIndex || (maxSize - wrIndex > packet.size())) {
        memcpy(buffer.data() + wrIndex, pktBuffer, copyed);
        wrIndex += copyed;
    } else {
        copyed = maxSize - wrIndex;
        memcpy(buffer.data() + wrIndex, pktBuffer, copyed);
        pktBuffer += copyed;
        copyed = static_cast<uint32_t>(packet.size()) - copyed;
        memcpy(buffer.data(), pktBuffer, copyed);
        wrIndex = copyed;
    }
    return true;
}

bool CircularBuffer::Get(TdcPacketHead &hdr, std::vector<uint8_t> &packet)
{
    if (GetCount() < sizeof(hdr)) {
        return false;
    }
    if (rdIndex < wrIndex) {
        memcpy(&hdr, buffer.data() + rdIndex, sizeof(hdr));
        if (hdr.dataLen + sizeof(hdr) > GetCount()) {
            return false;
        }
        packet.resize(hdr.dataLen);
        memcpy(packet.data(), buffer.data() + rdIndex + sizeof(hdr), hdr.dataLen);
        rdIndex += hdr.dataLen + sizeof(hdr);
    } else {
        if (maxSize - rdIndex > sizeof(hdr)) {
            memcpy(&hdr, buffer.data() + rdIndex, sizeof(hdr));
        } else {
            uint32_t copyed = maxSize - rdIndex;
            memcpy(&hdr, buffer.data() + rdIndex, copyed);
            memcpy(&hdr + copyed, buffer.data(), sizeof(hdr) - copyed);
        }
        if (hdr.dataLen + sizeof(hdr) > GetCount()) {
            return false;
        }
        rdIndex = (rdIndex + sizeof(hdr)) % maxSize;
        if (maxSize - rdIndex > hdr.dataLen) {
            memcpy(packet.data(), buffer.data() + rdIndex, hdr.dataLen);
        } else {
            uint32_t copyed = maxSize - rdIndex;
            memcpy(packet.data(), buffer.data() + rdIndex, copyed);
            memcpy(packet.data() + copyed, buffer.data(), hdr.dataLen - copyed);
        }
        rdIndex = (rdIndex + hdr.dataLen) % maxSize;
    }
    if (rdIndex == wrIndex) {
        rdIndex = 0;
        wrIndex = 0;
    }
    return true;
}

bool CircularBuffer::Get(TdcDataPacketHead &hdr, std::vector<uint8_t> &packet)
{
    if (GetCount() < sizeof(hdr)) {
        return false;
    }
    if (rdIndex < wrIndex) {
        memcpy(&hdr, buffer.data() + rdIndex, sizeof(hdr));
        if (hdr.dataLen + sizeof(hdr) > GetCount()) {
            return false;
        }
        packet.resize(hdr.dataLen);
        memcpy(packet.data(), buffer.data() + rdIndex + sizeof(hdr), hdr.dataLen);
        rdIndex += hdr.dataLen + sizeof(hdr);
    } else {
        if (maxSize - rdIndex > sizeof(hdr)) {
            memcpy(&hdr, buffer.data() + rdIndex, sizeof(hdr));
        } else {
            uint32_t copyed = maxSize - rdIndex;
            memcpy(&hdr, buffer.data() + rdIndex, copyed);
            memcpy(&hdr + copyed, buffer.data(), sizeof(hdr) - copyed);
        }
        if (hdr.dataLen + sizeof(hdr) > GetCount()) {
            return false;
        }
        rdIndex = (rdIndex + sizeof(hdr)) % maxSize;
        if (maxSize - rdIndex > hdr.dataLen) {
            memcpy(packet.data(), buffer.data() + rdIndex, hdr.dataLen);
        } else {
            uint32_t copyed = maxSize - rdIndex;
            memcpy(packet.data(), buffer.data() + rdIndex, copyed);
            memcpy(packet.data() + copyed, buffer.data(), hdr.dataLen - copyed);
        }
        rdIndex = (rdIndex + hdr.dataLen) % maxSize;
    }
    if (rdIndex == wrIndex) {
        rdIndex = 0;
        wrIndex = 0;
    }
    return true;
}

void CircularBuffer::Clear()
{
    rdIndex = 0;
    wrIndex = 0;
    if (!buffer.empty()) {
        memset(buffer.data(), 0, buffer.size());
    }
}