#pragma once

#include <stddef.h>
#include <stdarg.h>

typedef signed short        ee_s16;
typedef unsigned short      ee_u16;
typedef signed int          ee_s32;
typedef double              ee_f32;
typedef unsigned char       ee_u8;
typedef unsigned int        ee_u32;
typedef unsigned long int   ee_u64;
typedef ee_u64              ee_ptr_int;
typedef size_t              ee_size_t;

typedef ee_ptr_int CORE_TICKS;

#define MEM_METHOD MEM_STATIC

typedef struct CORE_PORTABLE_S
{
    ee_u8 portable_id;
} core_portable;

#ifndef MULTITHREAD
#define MULTITHREAD 1
#define USE_PTHREAD 0
#define USE_FORK    0
#define USE_SOCKET  0
#endif

#ifndef COMPILER_VERSION
#ifdef __GNUC__
#define COMPILER_VERSION "GCC" __VERSION__
#else
#define COMPILER_VERSION "Undefined compiler"
#endif
#endif

#ifndef COMPILER_FLAGS
#define COMPILER_FLAGS FLAGS_STR
#endif

#ifndef MEM_LOCATION
#define MEM_LOCATION "CVA6 ZCU111 1MiB local SRAM"
#endif

#ifndef SC_MEM_LOCATION
#define SC_MEM_LOCATION "CVA6_ZCU111_LOCAL_SRAM"
#endif

#ifndef SEED_METHOD
#define SEED_METHOD SEED_VOLATILE
#endif

#ifndef HAS_STDIO
#define HAS_STDIO 0
#endif

#ifndef HAS_PRINTF
#define HAS_PRINTF 1
#endif

#ifndef HAS_FLOAT
#define HAS_FLOAT 0
#endif

#ifndef MAIN_HAS_NOARGC
#define MAIN_HAS_NOARGC 1
#endif

#ifndef MAIN_HAS_NORETURN
#define MAIN_HAS_NORETURN 0
#endif

#ifndef SKIP_TIME_CHECK
#define SKIP_TIME_CHECK 0
#endif

#define align_mem(x) (void *)(8 + (((ee_ptr_int)(x) - 1) & ~7UL))
#define CORETIMETYPE ee_u64

extern ee_u32 default_num_contexts;

int printf(const char *fmt, ...);
void portable_init(core_portable *p, int *argc, char *argv[]);
void portable_fini(core_portable *p);
