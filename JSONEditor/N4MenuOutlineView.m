//
//  N4MenuOutlineView.m
//  Joodle
//
//  Created by Marc Bauer on 23.07.14.
//  Copyright (c) 2014 NumberFour. All rights reserved.
//

#import "N4MenuOutlineView.h"

@implementation N4MenuOutlineView

- (NSMenu *)menuForEvent:(NSEvent *)event
{
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    NSInteger row = [self rowAtPoint:location];
    NSInteger column = [self columnAtPoint:location];
    
    if (row == NSNotFound || column == NSNotFound) {
        return nil;
    }
    
    NSTableColumn *tableColumn = [self tableColumns][column];
    
    if ([self.delegate respondsToSelector:@selector(outlineView:menuInRow:column:)]) {
        return [(id<N4MenuOutlineViewDelegate>)self.delegate
            outlineView:self menuInRow:row column:tableColumn];
    }
    
    return nil;
}

- (void)keyDown:(NSEvent *)theEvent
{
    if (theEvent.keyCode == 51 && self.selectedRowIndexes.count > 0) {
        if ([self.delegate respondsToSelector:@selector(outlineView:shouldDeleteObjectInRow:)]) {
            [(id<N4MenuOutlineViewDelegate>)self.delegate outlineView:self
            	shouldDeleteObjectInRow:self.selectedRowIndexes.firstIndex];
            return;
        }
    }
    [super keyDown:theEvent];
}
@end