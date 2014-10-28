//
//  N4StylesReader.h
//  JSONEditor
//
//  Created by Christian Lippka on 28/10/14.
//  Copyright (c) 2014 NumberFour AG. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface N4StylesReader : NSObject

+ (void)readKeysFromURL:(NSURL*)url error:(NSError**)error;

+ (NSDictionary*)readStylesFromURL:(NSURL*)url error:(NSError**)error;

@end
