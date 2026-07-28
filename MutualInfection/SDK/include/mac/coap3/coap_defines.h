/*
 * cmake_coap_defines.h -- optional #defines used for building libcoap
 *
 * Copyright (C) 2024-2025 Jon Shallow <supjps-libcoap@jpshallow.com>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * This file is part of the CoAP library libcoap. Please see README for terms
 * of use.
 */

/**
 * @file coap_defines.h
 * @brief List of libcoap library build defines
 */

#ifndef COAP_DEFINES_H_
#define COAP_DEFINES_H_


/* Define to build support for Unix socket packets. */
#define COAP_AF_UNIX_SUPPORT 1

/* Define to 1 to build with support for async separate responses. */
#define COAP_ASYNC_SUPPORT 1

/* Define to 1 if libcoap supports client mode code. */
#define COAP_CLIENT_SUPPORT 1

/* Define to 1 if the system has small stack size. */
/* #undef COAP_CONSTRAINED_STACK */

/* Define to 1 to build without TCP support. */
#define COAP_DISABLE_TCP 0

/* Define to 1 if the system has epoll support. */
/* #undef COAP_EPOLL_SUPPORT */

/* Define to build support for IPv4 packets. */
#define COAP_IPV4_SUPPORT 1

/* Define to build support for IPv6 packets. */
#define COAP_IPV6_SUPPORT 1

/* Define to level if max logging level is not 8 */
/* #undef COAP_MAX_LOGGING_LEVEL */

/* Define to 1 to build with OSCORE support. */
#define COAP_OSCORE_SUPPORT 1

/* Define to 1 if libcoap supports proxy code. */
#define COAP_PROXY_SUPPORT 1

/* Define to 1 to build with Q-Block support. */
#define COAP_Q_BLOCK_SUPPORT 1

/* Define to 1 if libcoap supports server mode code. */
#define COAP_SERVER_SUPPORT 1

/* Define to 1 if libcoap has thread number logging support */
#define COAP_THREAD_NUM_LOGGING 1

/* Define to 1 detect recursive locking detection support */
#define COAP_THREAD_RECURSIVE_CHECK 1

/* Define to 1 if libcoap has thread safe support */
#define COAP_THREAD_SAFE 1

/* Define to 1 if the system has libgnutls28. */
/* #undef COAP_WITH_LIBGNUTLS */

/* Define to 1 if the system has libmbedtls2.7.10. */
/* #undef COAP_WITH_LIBMBEDTLS */

/* Define to 1 if the system has libssl1.1. */
#define COAP_WITH_LIBOPENSSL 1

/* Define to 1 if the system has libtinydtls. */
/* #undef COAP_WITH_LIBTINYDTLS */

/* Define to 1 if the system has libwolfssl. */
/* #undef COAP_WITH_LIBWOLFSSL */

/* Define to 1 to build support for persisting observes. */
#define COAP_WITH_OBSERVE_PERSIST 1

/* Define to 1 to build with WebSockets support. */
#define COAP_WS_SUPPORT 1

#endif /* COAP_DEFINES_H_ */
