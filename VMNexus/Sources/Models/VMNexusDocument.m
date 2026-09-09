//
//  VMNexusDocument.m
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusDocument.h"

@implementation VMNexusDocument

- (instancetype)init {
    self = [super init];
    if (self) {
        _virtualMachine = [VMNexusVirtualMachine virtualMachineWithName:@"New VM" architecture:VMNexusArchX86_64];
    }
    return self;
}

+ (BOOL)autosavesInPlace { return YES; }

- (void)makeWindowControllers {
    // The library window controller manages this
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    [self.virtualMachine saveToBundle];
    NSString *configPath = [self.virtualMachine.vmBundlePath stringByAppendingPathComponent:@"vm.json"];
    NSData *data = [NSData dataWithContentsOfFile:configPath];
    if (!data && outError) {
        *outError = [NSError errorWithDomain:@"VMNexus" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to save VM"}];
    }
    return data;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    if (!self.virtualMachine) {
        self.virtualMachine = [[VMNexusVirtualMachine alloc] init];
    }
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:outError];
    if (dict) {
        [self.virtualMachine loadFromDictionary:dict];
    }
    return dict != nil;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError {
    if (!self.virtualMachine) {
        self.virtualMachine = [[VMNexusVirtualMachine alloc] init];
    }
    NSString *path = url.path;
    self.virtualMachine.vmBundlePath = path;
    return [self.virtualMachine loadFromBundle:path];
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError {
    self.virtualMachine.vmBundlePath = url.path;
    return [self.virtualMachine saveToBundle];
}

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName { return YES; }

@end
