//
//  N4Document.m
//  JSONEditor
//
//  Created by Marc Bauer on 27.08.14.
//  Copyright (c) 2014 NumberFour AG. All rights reserved.
//

#import "N4Document.h"
#import "N4StylesReader.h"
#import "N4MenuOutlineView.h"

@interface N4Document () <NSTableViewDataSource>
@end

typedef NS_ENUM(NSUInteger, N4JSONType) {
    N4JSONTypeUndefined,
    N4JSONTypeArray,
    N4JSONTypeDictionary
};

@interface N4JSONNode : NSObject
+ (instancetype)JSONNodeWithKey:(NSString *)key object:(id)object;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) id value;
@property (nonatomic, readonly) NSUInteger numberOfChildren;

- (N4JSONNode *)childAtIndex:(NSUInteger)idx;
- (void)deleteChild:(id)aChild;

- (BOOL)writeToURL:(NSURL *)anURL error:(NSError **)error;
@end


@implementation N4Document
{
    N4JSONNode *_rootNode;
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
    return [_rootNode writeToURL:url error:outError];
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

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    if( [typeName isEqualToString:@"iOSBinary"])
    {
        // we need to read the keys file
        [N4StylesReader readKeysFromURL:absoluteURL error:outError];
        if( outError && *outError )
            return NO;

        id obj = [N4StylesReader readStylesFromURL:absoluteURL error:outError];

        if( obj != nil )
            _rootNode = [N4JSONNode JSONNodeWithKey:@"<root>" object:obj];

        return obj != nil;
    }
    else
    {
        return [self readFromData:[NSData dataWithContentsOfURL:absoluteURL] ofType:typeName error:outError];
    }
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

- (NSMenu *)outlineView:(N4MenuOutlineView *)outlineView
    menuInRow:(NSInteger)row column:(NSTableColumn *)column
{
    N4JSONNode *node = [outlineView itemAtRow:row];
    
    if (node.numberOfChildren == 0) {
        return nil;
    }
    
    NSMenu *menu = [[NSMenu alloc] init];
    
    NSMenuItem *menuItem = [[NSMenuItem alloc]
        initWithTitle:[NSString stringWithFormat:@"Export '%@'…", node.name]
        action:@selector(exportNode:)
        keyEquivalent:@""];
    menuItem.target = self;
    menuItem.representedObject = node;
    [menu addItem:menuItem];
    
    return menu;
}

- (void)outlineView:(N4MenuOutlineView *)outlineView
    shouldDeleteObjectInRow:(NSInteger)row
{
    N4JSONNode *node = [outlineView itemAtRow:row];
    N4JSONNode *parentNode = [outlineView parentForItem:node];
    [parentNode deleteChild:node];
    [outlineView reloadData];
}



#pragma mark - Action Methods

- (void)exportNode:(NSMenuItem *)sender
{
    N4JSONNode *node = sender.representedObject;
    
    NSString *directoryPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"SaveDirectory"];
    if (directoryPath == nil) {
        directoryPath = [@"~/Desktop" stringByExpandingTildeInPath];
    }
    
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"json"];
    savePanel.allowsOtherFileTypes = NO;
    [savePanel setExtensionHidden:NO];
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:directoryPath]];
    [savePanel setNameFieldStringValue:node.name];
    
    if ([savePanel runModal] != NSOKButton) {
        return;
    }
    
    [[NSUserDefaults standardUserDefaults] setValue:savePanel.directoryURL.path
        forKey:@"SaveDirectory"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSError *error;
    if (![node writeToURL:savePanel.URL error:&error]) {
        [self presentError:error];
    }
}
@end



@implementation N4JSONNode
{
    NSMutableArray *_childNodes;
    N4JSONType _type;
}

+ (instancetype)JSONNodeWithKey:(NSString *)key object:(id)object
{
    NSMutableArray *childNodes;
    N4JSONType jsonType = N4JSONTypeUndefined;
    
    if ([object isKindOfClass:[NSDictionary class]]) {
        jsonType = N4JSONTypeDictionary;
        NSArray *keys = [[(NSDictionary *)object allKeys] sortedArrayUsingSelector:
        	@selector(caseInsensitiveCompare:)];
        childNodes = [NSMutableArray new];
        
        for (NSString *key in keys) {
            id value = ((NSDictionary *)object)[key];
            [childNodes addObject:[N4JSONNode JSONNodeWithKey:key object:value]];
        }
        object = [NSString stringWithFormat:@"%ld key/value pairs", ((NSDictionary *)object).count];
    } else if ([object isKindOfClass:[NSArray class]]) {
        jsonType = N4JSONTypeArray;
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
    node->_childNodes = childNodes;
    node->_name = [key copy];
    node->_value = object;
    node->_type = jsonType;
    
    return node;
}

- (N4JSONNode *)childAtIndex:(NSUInteger)idx
{
    return _childNodes[idx];
}

- (void)deleteChild:(id)aChild
{
    NSUInteger idx = [_childNodes indexOfObject:aChild];
    if (idx == NSNotFound) {
        return;
    }
    [_childNodes removeObject:aChild];
    _numberOfChildren--;
}

- (id)rawValue
{
    switch (_type) {
        case N4JSONTypeUndefined:
            return _value;
        
        case N4JSONTypeArray: {
            NSMutableArray *arr = [NSMutableArray new];
            for (N4JSONNode *childNode in _childNodes) {
                [arr addObject:[childNode rawValue]];
            }
            return arr;
        }
        
        case N4JSONTypeDictionary: {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            for (N4JSONNode *childNode in _childNodes) {
                dict[childNode.name] = [childNode rawValue];
            }
            return dict;
        }
    }
}

- (BOOL)writeToURL:(NSURL *)anURL error:(NSError **)error
{
    BOOL success;
    
    NSOutputStream *outputStream = [NSOutputStream outputStreamWithURL:anURL append:NO];
    
    [outputStream open];
    success = [NSJSONSerialization writeJSONObject:[self rawValue] toStream:outputStream
    	options:NSJSONWritingPrettyPrinted error:error] > 0;
    [outputStream close];
    
    return success;
}
@end