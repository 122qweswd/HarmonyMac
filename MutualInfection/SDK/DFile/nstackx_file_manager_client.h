/*
 * Copyright (C) 2021 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef NSTACKX_FILE_MANAGER_CLIENT_H
#define NSTACKX_FILE_MANAGER_CLIENT_H

#include "nstackx_file_manager.h"

#ifdef __cplusplus
extern "C" {
#endif

void SendTaskProcess(FileManager *fileManager, FileListTask *fileList);

void ClearSendFileList(FileManager *fileManager, FileListTask *fileList);

int32_t InitSendBlockLists(FileManager *fileManager);

uint32_t GetMaxSendListSize(uint16_t connType);

uint16_t GetSendListNum(void);

void ClearSendFrameList(FileManager *fileManager);

/* 创建读缓存实例，fd 必须已打开只读 */
seq_reader *sr_create(int fd, uint32_t cache_size);
 
/* 读取 [offset, offset+len) 到 buf；返回 0 成功，-1 失败 */
int sr_read(int fd, seq_reader *sr, uint64_t offset, void *buf, uint32_t len);
 
/* 关闭并释放 */
void sr_close(seq_reader *sr);
#ifdef __cplusplus
}
#endif

#endif
