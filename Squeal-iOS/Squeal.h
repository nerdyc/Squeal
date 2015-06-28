//
//  Squeal-iOS.h
//  Squeal-iOS
//
//  Created by Christian Niles on 9/14/14.
//  Copyright (c) 2014 Vulpine Labs LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for Squeal-iOS.
FOUNDATION_EXPORT double Squeal_iOSVersionNumber;

//! Project version string for Squeal-iOS.
FOUNDATION_EXPORT const unsigned char Squeal_iOSVersionString[];

// sqlite uses some magic function pointers to represent pre-defined destructor behavior when
// working with blobs. Those are not imported into Swift because they are pre-processor macros. So
// those magic numbers are copied here.
//
// https://www.sqlite.org/c3ref/c_static.html
//
typedef void (*squeal_destructor_type)(void*);
const squeal_destructor_type SQUEAL_STATIC = ((squeal_destructor_type)0);
const squeal_destructor_type SQUEAL_TRANSIENT = ((squeal_destructor_type)-1);
