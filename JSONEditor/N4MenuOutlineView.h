//
//  N4MenuOutlineView.h
//  Joodle
//
//  Created by Marc Bauer on 23.07.14.
//  Copyright (c) 2014 NumberFour. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class N4MenuOutlineView;

@interface N4MenuOutlineView : NSOutlineView
@end



@protocol N4MenuOutlineViewDelegate
@optional
- (NSMenu *)outlineView:(N4MenuOutlineView *)outlineView
    menuInRow:(NSInteger)row column:(NSTableColumn *)column;
- (void)outlineView:(N4MenuOutlineView *)outlineView
    shouldDeleteObjectInRow:(NSInteger)row;
@end