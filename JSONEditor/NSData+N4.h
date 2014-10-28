//
//  NSData+N4.h
//  JSONEditor
//
//  Created by Christian Lippka on 28/10/14.
//  Copyright (c) 2014 NumberFour AG. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (N4)

- (NSData*)zlibInflate;
- (NSData*)zlibDeflate;
- (NSData*)gzipInflate;
- (NSData*)gzipDeflate;

@end
