#import <Foundation/Foundation.h>

//! Project version number for Squeal.
FOUNDATION_EXPORT double SquealVersionNumber;

//! Project version string for Squeal.
FOUNDATION_EXPORT const unsigned char SquealVersionString[];

// sqlite uses some magic function pointers to represent pre-defined destructor behavior when
// working with blobs. Those are not imported into Swift because they are pre-processor macros. So
// those magic numbers are copied here.
//
// https://www.sqlite.org/c3ref/c_static.html
//
typedef void (*squeal_destructor_type)(void*);
const squeal_destructor_type SQUEAL_STATIC = ((squeal_destructor_type)0);
const squeal_destructor_type SQUEAL_TRANSIENT = ((squeal_destructor_type)-1);
