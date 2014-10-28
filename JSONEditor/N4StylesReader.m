//
//  N4StylesReader.m
//  JSONEditor
//
//  Created by Christian Lippka on 28/10/14.
//  Copyright (c) 2014 NumberFour AG. All rights reserved.
//

#import "N4StylesReader.h"
#import "NSData+N4.h"

const uint16_t N4_BINARY_TYPE_NUMBER8 = 1;
const uint16_t N4_BINARY_TYPE_NUMBER16 = 2;
const uint16_t N4_BINARY_TYPE_NUMBER32 = 3;
const uint16_t N4_BINARY_TYPE_FLOAT = 4;
const uint16_t N4_BINARY_TYPE_STRING = 5;
const uint16_t N4_BINARY_TYPE_DICTIONARY = 6;
const uint16_t N4_BINARY_TYPE_BOOLEAN = 7;
const uint16_t N4_BINARY_TYPE_ARRAY = 8;

@interface N4UIDLBinaryReader : NSObject

@property (nonatomic,strong) NSError *error;

-(id)initWithStream:(NSInputStream *)inputStream;
- (int8_t)Int8;
- (uint8_t)UInt8;
- (int16_t)Int16;
- (int32_t)Int32;
- (float)Float;
-(NSData *)readDataOfLength:(NSUInteger)bytesToRead;
-(NSString *)readStringWithEncoding:(NSStringEncoding)stringEncoding;

@end

@implementation N4UIDLBinaryReader
{
    NSInputStream *_stream;
}

-(id)initWithStream:(NSInputStream *)inputStream
{
    self = [self init];
    if(self)
    {
        _stream = inputStream;
    }
    return self;
}

#pragma mark - Reading methods

- (void)read:(uint8_t *)buffer length:(NSUInteger)len
{
    self.error = nil;

    NSInteger readResult = [_stream read:buffer maxLength:len];
    if (readResult == -1)
    {
        self.error = [NSError errorWithDomain:NSInternalInconsistencyException code:0 userInfo:nil];
    }
    else if (readResult == 0)
    {
        self.error = [NSError errorWithDomain:NSInternalInconsistencyException code:1 userInfo:@{NSLocalizedDescriptionKey: @"End of stream reached."}];
    }
    else if (readResult > 0 && readResult < len)
    {
        self.error = [NSError errorWithDomain:NSInternalInconsistencyException code:2 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Needed to read %zu bytes, but read only %d.", (size_t)len, (int)readResult]}];
    }
}

- (int8_t)Int8
{
    uint8_t internalValue;
    [self read:(uint8_t*)&internalValue length:sizeof(uint8_t)];
    int8_t* returnValue = (int8_t*)&internalValue;
    return *returnValue;
}

- (uint8_t)UInt8
{
    uint8_t internalValue;
    [self read:(uint8_t*)&internalValue length:sizeof(uint8_t)];
    return internalValue;
}

- (uint16_t)UInt16
{
    uint16_t internalValue;
    [self read:(uint8_t*)&internalValue length:sizeof(uint16_t)];
    internalValue = CFSwapInt16BigToHost(internalValue);
    return internalValue;
}

- (int16_t)Int16
{
    uint16_t internalValue;
    [self read:(uint8_t*)&internalValue length:sizeof(uint16_t)];
    internalValue = CFSwapInt16BigToHost(internalValue);
    int16_t* returnValue = (int16_t*)&internalValue;
    return *returnValue;
}

- (int32_t)Int32
{
    uint32_t internalValue;
    [self read:(uint8_t*)&internalValue length:sizeof(uint32_t)];
    internalValue = CFSwapInt32BigToHost(internalValue);
    int32_t* returnValue = (int32_t*)&internalValue;
    return *returnValue;
}

- (float)Float
{
    uint32_t internalValue;
    [self read:(uint8_t*)&internalValue length:sizeof(uint32_t)];
    internalValue = CFSwapInt32BigToHost(internalValue);
    float* returnValue = (float*)&internalValue;
    return *returnValue;
}

-(NSData *)readDataOfLength:(NSUInteger)bytesToRead
{
    self.error = nil;
    NSData* result = nil;

    uint8_t* readBuffer = malloc(bytesToRead);
    NSInteger numberOfByteRead = [_stream read:readBuffer maxLength:bytesToRead];

    if (numberOfByteRead == bytesToRead)
    {
        result = [NSData dataWithBytesNoCopy:readBuffer length:numberOfByteRead freeWhenDone:YES];
    }
    else if (numberOfByteRead > 0)
    {
        result = [NSData dataWithBytes:readBuffer length:numberOfByteRead];
        self.error = [NSError errorWithDomain:NSInternalInconsistencyException code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Needed to read %d bytes, but read only %d.", (int)bytesToRead, (int)numberOfByteRead]}];
        free(readBuffer);
    }
    else if (numberOfByteRead == 0)
    {
        result = [NSData data];
        self.error = [NSError errorWithDomain:NSInternalInconsistencyException code:1 userInfo:@{NSLocalizedDescriptionKey: @"End of stream reached."}];
        free(readBuffer);
    }
    else // numberOfBytesRead == -1
    {
        [NSError errorWithDomain:NSInternalInconsistencyException code:2 userInfo:nil];
        free(readBuffer);
    }

    return result;
}


-(NSString *)readStringWithEncoding:(NSStringEncoding)stringEncoding
{
    self.error = nil;

    NSString *string;

    NSUInteger bytesToRead = [self UInt8];
    if( !self.error )
    {
        if( bytesToRead == 0xff )
            bytesToRead = [self Int32];
        else if( bytesToRead == 0 )
            return @"";
    }

    if( !self.error )
    {
        NSData* stringBytes = [self readDataOfLength:bytesToRead];

        if( !self.error )
        {
            string = [[NSString alloc] initWithData:stringBytes encoding:stringEncoding];
        }
    }

    return string;
}

@end

static NSDictionary *_keys;

@implementation N4StylesReader
{
    NSInputStream *_stream;
}

#pragma mark - binary reading

+ (void)readKeysFromURL:(NSURL*)url error:(NSError**)error
{
    NSString *filePath = [[[[url filePathURL] path] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"keys.bin"];

    if( !filePath )
        [NSException raise:NSInternalInconsistencyException format:@"File keys.bin not found next to styles file!"];

    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:filePath];

    [stream open];

    N4UIDLBinaryReader *reader = [[N4UIDLBinaryReader alloc] initWithStream:stream];

    NSMutableDictionary *keys = [NSMutableDictionary new];

    NSUInteger keyCount = [reader Int32];
    while(keyCount--)
    {
        int32_t uid = [reader Int32];
        [keys setObject:[reader readStringWithEncoding:NSUTF8StringEncoding] forKey:@(uid)];
    }

    [stream close];

    _keys = [keys copy];
}

+ (NSDictionary*)readStylesFromURL:(NSURL*)url error:(NSError**)error
{
    NSParameterAssert(error);
    NSParameterAssert(_keys);

    NSDictionary *ret;

    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if( !*error )
    {
        data = [data gzipInflate];
        NSInputStream *stream = [NSInputStream inputStreamWithData:data];

        [stream open];

        N4UIDLBinaryReader *reader = [[N4UIDLBinaryReader alloc] initWithStream:stream];

        ret = [self readDictionary:reader];

        *error =reader.error;

        [stream close];
    }

    return *error ? nil : ret;
}

+ (id)readValue:(N4UIDLBinaryReader*)reader key:(NSString**)key array:(BOOL)array
{
    uint8_t type = [reader UInt8];
    if( type == 0 )
        return nil;

    int32_t keyIndex = !array ? [reader Int32] : 0;

    if( key )
        *key = _keys[@(keyIndex)];

    if( !reader.error )
    {
        switch (type)
        {
            case N4_BINARY_TYPE_NUMBER8:
                return @([reader Int8]);
            case N4_BINARY_TYPE_NUMBER16:
                return @([reader Int16]);
            case N4_BINARY_TYPE_NUMBER32:
                return @([reader Int32]);
            case N4_BINARY_TYPE_FLOAT:
                return @([reader Float]);
            case N4_BINARY_TYPE_STRING:
                return [reader readStringWithEncoding:NSUTF8StringEncoding];
            case N4_BINARY_TYPE_DICTIONARY:
                return [self readDictionary:reader];
            case N4_BINARY_TYPE_BOOLEAN:
                return @( [reader UInt8] != 0 ? YES : NO);
            case N4_BINARY_TYPE_ARRAY:
            {
                NSMutableArray *array = [NSMutableArray new];

                id value;
                while( !reader.error )
                {
                    value = [self readValue:reader key:nil array:YES];
                    if( value )
                        [array addObject:value];
                    else
                        break;
                }

                return [array copy];
            }
        }
    }

    return nil;
}

+ (NSDictionary*)readDictionary:(N4UIDLBinaryReader*)reader
{
    NSMutableDictionary *ret = [NSMutableDictionary new];
    id value;
    NSString *key;
    
    while( !reader.error )
    {
        value = [self readValue:reader key:&key array:NO];
        if( value )
            [ret setObject:value forKey:key ? key : [NSString stringWithFormat:@"Unknown %d",rand()]];
        else
            break;
    }
    
    return [ret copy];
}


@end
