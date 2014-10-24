//
//  N4Document.m
//  JSONEditor
//
//  Created by Marc Bauer on 27.08.14.
//  Copyright (c) 2014 NumberFour AG. All rights reserved.
//

#import "N4Document.h"

@interface N4Document () <NSTableViewDataSource>
@end

@interface N4JSONNode : NSObject
+ (instancetype)JSONNodeWithKey:(NSString *)key object:(id)object;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) id value;
@property (nonatomic, readonly) NSUInteger numberOfChildren;

- (N4JSONNode *)childAtIndex:(NSUInteger)idx;
@end

@implementation N4Document
{
    N4JSONNode *_rootNode;
}

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
    }
    return self;
}

- (NSString *)windowNibName
{
    return @"N4Document";
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError
{
    return NO;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    id obj = [NSJSONSerialization JSONObjectWithData:data
    	options:NSJSONReadingAllowFragments error:outError];
    
    if (obj != nil) {
        _rootNode = [N4JSONNode JSONNodeWithKey:@"<root>" object:obj];
    }
    
    return obj != nil;
}



#pragma mark - NSOutlineViewDataSource Methods

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(N4JSONNode *)item
{
    if (item == nil) {
        item = _rootNode;
    }
    return [item childAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(N4JSONNode *)item
{
    if (item == nil) {
        item = _rootNode;
    }
    return item.numberOfChildren > 0;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(N4JSONNode *)item
{
    if (item == nil) {
        item = _rootNode;
    }
    return item.numberOfChildren;
}

- (id)outlineView:(NSOutlineView *)outlineView
    objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(N4JSONNode *)item
{
    if ([tableColumn.identifier isEqualToString:@"Key"]) {
        return item.name;
    } else if ([tableColumn.identifier isEqualToString:@"Value"]) {
        return item.value;
    }
    
    return @"???";
}
@end



@implementation N4JSONNode
{
    NSArray *_childNodes;
}

+ (instancetype)JSONNodeWithKey:(NSString *)key object:(id)object
{
    NSMutableArray *childNodes;
    
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSArray *keys = [[(NSDictionary *)object allKeys] sortedArrayUsingSelector:
        	@selector(caseInsensitiveCompare:)];
        childNodes = [NSMutableArray new];
        
        for (NSString *key in keys) {
            id value = ((NSDictionary *)object)[key];
            [childNodes addObject:[N4JSONNode JSONNodeWithKey:key object:value]];
        }
        object = [NSString stringWithFormat:@"%ld key/value pairs", ((NSDictionary *)object).count];
    } else if ([object isKindOfClass:[NSArray class]]) {
        childNodes = [NSMutableArray new];
        
        NSUInteger count = ((NSArray *)object).count;
        for (NSUInteger idx = 0; idx < count; idx++) {
            id value = ((NSArray *)object)[idx];
            [childNodes addObject:[N4JSONNode
            	JSONNodeWithKey:[NSString stringWithFormat:@"[%ld]", idx] object:value]];
        }
        object = [NSString stringWithFormat:@"%ld items", count];
    } else {
        object = [object description];
    }
    
    N4JSONNode *node = [N4JSONNode new];
    node->_numberOfChildren = childNodes.count;
    node->_childNodes = [childNodes copy];
    node->_name = [key copy];
    node->_value = object;
    
    return node;
}

- (N4JSONNode *)childAtIndex:(NSUInteger)idx
{
    return _childNodes[idx];
}
@end