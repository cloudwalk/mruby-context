/**
 * @file inf_debug.h
 * @brief API definition.
 * @platform Pax Prolin
 * @date 2020-11-21
 * 
 * @copyright Copyright (c) 2020 CloudWalk, Inc.
 * 
 */

#ifndef _INF_DEBUG_H_INCLUDED_
#define _INF_DEBUG_H_INCLUDED_

#include <string.h>

/**********/
/* Macros */
/**********/

#define INF_SERIAL 0
#define INF_LOGCAT 1

#define _INF_DEBUG_ /* TODO: move to Makefile!? */

#ifdef _INF_DEBUG_
#ifndef INF_TRACE
#define INF_TRACE(...) inf_debug_send("\r\n%s %s %s %d %s ", __DATE__, __TIME__, __INF_FILE__, __LINE__, __FUNCTION__); inf_debug_send(__VA_ARGS__)
#endif /* #ifndef INF_TRACE */
#else
#ifndef INF_TRACE
#define INF_TRACE(...)
#endif /* #ifndef INF_TRACE */
#endif /* #ifdef _INF_DEBUG_ */

/********************/
/* Public functions */
/********************/

extern void
inf_debug_init(void);

extern void
inf_debug_send(const char *format, ...);

#endif /* #ifndef _INF_DEBUG_H_INCLUDED_ */
