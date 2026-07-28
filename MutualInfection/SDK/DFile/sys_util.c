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

#include "nstackx_util.h"
#include "nstackx_error.h"
#include "nstackx_list.h"
#include "nstackx_log.h"
#include "securec.h"
#include "sys_epoll.h"
#include "PrefixHeader.pch"
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
#include <dispatch/dispatch.h>
#endif
#define TAG "nStackXUtil"

typedef struct stSemList {
    List link;
    uint32_t no;
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
    dispatch_semaphore_t dispatchSem;
#else
    sem_t *sem;
#endif
} SemListNode;

static SemListNode g_semListHead;
static pthread_mutex_t g_semMutex = PTHREAD_MUTEX_INITIALIZER;
static uint32_t g_semNO = 0;

static const char *g_illegalPathString[] = {
    "/../",
};

static const char *g_illegalPathHeadString[] = {
    "../",
};

uint8_t IsFileNameLegal(const char *fileName)
{
    if (fileName == NULL || strlen(fileName) == 0) {
        return NSTACKX_FALSE;
    }

    for (uint32_t idx = 0; idx < sizeof(g_illegalPathHeadString) / sizeof(g_illegalPathHeadString[0]); idx++) {
        if (g_illegalPathHeadString[idx] == NULL || strlen(fileName) < strlen(g_illegalPathHeadString[idx])) {
            continue;
        }
        if (memcmp(fileName, g_illegalPathHeadString[idx], strlen(g_illegalPathHeadString[idx])) == 0) {
            LOGE(TAG, "illegal filename");
            return NSTACKX_FALSE;
        }
    }

    for (uint32_t idx = 0; idx < sizeof(g_illegalPathString) / sizeof(g_illegalPathString[0]); idx++) {
        if (g_illegalPathString[idx] == NULL || strlen(fileName) < strlen(g_illegalPathString[idx])) {
            continue;
        }
        if (strstr(fileName, g_illegalPathString[idx]) != NULL) {
            LOGE(TAG, "illegal filename");
            return NSTACKX_FALSE;
        }
    }
    return NSTACKX_TRUE;
}

int32_t GetCpuNum(void)
{
    return 1;
}

void StartThreadBindCore(int32_t cpu)
{
    (void)cpu;
}

void SetThreadName(const char *name)
{
    /* liteos only support set thread name when create */
    (void)name;
}

void BindThreadToTargetMask(pid_t tid, uint32_t cpuMask)
{
    (void)tid;
    (void)cpuMask;
}

void SetMaximumPriorityForThread(void)
{
}

void ClockGetTime(clockid_t id, struct timespec *tp)
{
    if (clock_gettime(id, tp) != 0) {
        LOGE(TAG, "clock_gettime error: %d", errno);
    }
}

int32_t SemInit(sem_t **sem, int pshared, unsigned int value)
{
    char temp[16] = { 0 };
    uint32_t no = 0;
    SemListNode *node = calloc(1, sizeof(SemListNode));
    if (node == NULL) {
        LOGE(TAG, "Fail to alloc sem node: %s", strerror(errno));
        return -1;
    }
    pthread_mutex_lock(&g_semMutex);
    if (g_semNO == 0) {
        ListInitHead(&g_semListHead.link);
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
        g_semListHead.dispatchSem = 0;
#else
        g_semListHead.sem = SEM_FAILED;
#endif
    }
    no = ++g_semNO;
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
    dispatch_semaphore_t dispatchSem = dispatch_semaphore_create(value);
    if (dispatchSem < 0) {
        LOGE(TAG, "Fail to create sem: %s", strerror(errno));
        pthread_mutex_unlock(&g_semMutex);
        return -1;
    }
    node->dispatchSem = dispatchSem;
    *sem = (sem_t*)dispatchSem;
#else
    snprintf_s(temp, sizeof(temp) - 1, sizeof(temp) - 1, "/sem%d", no);
    *sem = sem_open(temp, O_CREAT | O_EXCL, S_IRUSR | S_IWUSR, value);
    LOGE(TAG, "init sem%d with %d, sem_id %d", no, value, *sem);
    if (*sem == SEM_FAILED) {
        if (sem_unlink(temp) != 0) {
            LOGE(TAG, "Fail to remove sem file: %s", strerror(errno));
            pthread_mutex_unlock(&g_semMutex);
            return -1;
        }
        LOGE(TAG, "remove sem file and re-init again");
        *sem = sem_open(temp, O_CREAT | O_EXCL, S_IRUSR | S_IWUSR, value);
    }
    if (*sem == SEM_FAILED) {
        LOGE(TAG, "Fail to create sem: %s", strerror(errno));
        pthread_mutex_unlock(&g_semMutex);
        return -1;
    }
    node->sem = *sem;
#endif
    node->no = g_semNO;
    ListInsertHead(&(g_semListHead.link), &(node->link));
    pthread_mutex_unlock(&g_semMutex);

    return 0;
}

void SemGetValue(sem_t *sem, int *sval)
{
//    if (sem_getvalue(sem, sval) != 0) {
//        LOGE(TAG, "sem get error[%d]: %s", errno, strerror(errno));
//    }
}

void SemPost(sem_t **bridge)
{
    if (bridge != NULL) {
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
        dispatch_semaphore_t sem = (dispatch_semaphore_t)(*bridge);
        if (sem != NULL) {
            dispatch_semaphore_signal(sem);
        }
#else
        sem_t* sem = *bridge;
        if (sem_post(sem) != 0) {
            LOGE(TAG, "sem post error: %d", errno);
        }
#endif
    }
}

void SemWait(sem_t **bridge)
{
    if (bridge != NULL) {
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
        dispatch_semaphore_t sem = (dispatch_semaphore_t)(*bridge);
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
#else
        sem_t *sem = *bridge;
        if (sem_wait(sem) != 0) {
            perror("sem_wait");
            LOGE(TAG, "sem wait error: %d", errno);
        }
#endif
    }
}

void SemDestroy(sem_t **bridge)
{
    if (bridge != NULL) {
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
        dispatch_semaphore_t sem = (dispatch_semaphore_t)(*bridge);
#else
        sem_t *sem = *bridge;
        if (sem_close(sem) != 0) {
            LOGE(TAG, "sem destroy error: %s", strerror(errno));
        }
#endif
        pthread_mutex_lock(&g_semMutex);
        List *node = g_semListHead.link.next;
        while (node != &g_semListHead.link) {
            SemListNode *semNode = container_of(node, SemListNode, link);
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
            if (semNode->dispatchSem == sem) {
#else
            if (semNode->sem == sem) {
#endif
                ListRemoveNode(node);
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
                semNode->dispatchSem = NULL;
#else
                char temp[16];
                snprintf_s(temp, sizeof(temp) - 1, sizeof(temp) - 1, "/sem%d", semNode->no);
                if (sem_unlink(temp) != 0) {
                    LOGE(TAG, "Failed to unlink sem file[%s]: %s", temp, strerror(errno));
                }
#endif
                break;
            }
            node = node->next;
        }
        LOGE(TAG, "remove sem: %d", sem);
        pthread_mutex_unlock(&g_semMutex);
    }
}

int32_t PthreadCreate(pthread_t *tid, const pthread_attr_t *attr, void *(*entry)(void *), void *arg)
{
    return pthread_create(tid, attr, entry, arg);
}

void PthreadJoin(pthread_t thread, void **retval)
{
    if (pthread_join(thread, retval) != 0) {
        LOGE(TAG, "pthread_join failed error: %d", errno);
    }
}

int32_t PthreadMutexInit(pthread_mutex_t *mutex, const pthread_mutexattr_t *attr)
{
    return pthread_mutex_init(mutex, attr);
}

void PthreadMutexDestroy(pthread_mutex_t *mutex)
{
    if (pthread_mutex_destroy(mutex) != 0) {
        LOGE(TAG, "pthread mutex destroy error: %d", errno);
    }
}

int32_t PthreadMutexLock(pthread_mutex_t *mutex)
{
    return pthread_mutex_lock(mutex);
}

int32_t PthreadMutexUnlock(pthread_mutex_t *mutex)
{
    return pthread_mutex_unlock(mutex);
}

void CloseDesc(int32_t desc)
{
    CloseDescClearEpollPtr(desc);
    if (close(desc) != 0) {
        LOGE(TAG, "close desc error : %d", errno);
    }
}

