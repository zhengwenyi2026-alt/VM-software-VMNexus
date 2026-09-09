//
//  VMNexusHatariProcess.m
//  VMNexus
//
//  Hatari Atari ST engine wrapper.
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusHatariProcess.h"
#import "VMNexusEngineSelector.h"

@interface VMNexusHatariProcess ()
@property (nonatomic, strong, readwrite) VMNexusVirtualMachine *virtualMachine;
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, strong) NSTask *task;
@end

@implementation VMNexusHatariProcess

@synthesize delegate;

- (VMNexusEngineType)engineType { return VMNexusEngineTypeHatari; }

- (instancetype)initWithVirtualMachine:(VMNexusVirtualMachine *)vm {
    self = [super init];
    if (self) { _virtualMachine = vm; _isRunning = NO; }
    return self;
}

- (BOOL)startWithError:(NSError **)error {
    NSString *binPath = [VMNexusEngineSelector executablePathForEngineType:VMNexusEngineTypeHatari];
    if (!binPath) {
        if (error) *error = [NSError errorWithDomain:@"VMNexus" code:1001
            userInfo:@{NSLocalizedDescriptionKey: @"Hatari not found. Please install Hatari."}];
        return NO;
    }

    self.task = [[NSTask alloc] init];
    self.task.executableURL = [NSURL fileURLWithPath:binPath];
    NSMutableArray *args = [NSMutableArray array];
    if (self.virtualMachine.floppyAPath.length > 0) {
        [args addObjectsFromArray:@[@"--disk-a", self.virtualMachine.floppyAPath]];
    }
    if (self.virtualMachine.diskImagePath.length > 0) {
        [args addObjectsFromArray:@[@"--harddrive", self.virtualMachine.diskImagePath]];
    }
    self.task.arguments = args;

    NSPipe *outPipe = [NSPipe pipe], *errPipe = [NSPipe pipe];
    self.task.standardOutput = outPipe; self.task.standardError = errPipe;

    __weak typeof(self) weakSelf = self;
    outPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *fh) {
        NSData *d = fh.availableData; if (d.length) [weakSelf.delegate engine:weakSelf didOutputData:d];
    };
    errPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *fh) {
        NSData *d = fh.availableData; if (d.length) [weakSelf.delegate engine:weakSelf didOutputError:d];
    };
    self.task.terminationHandler = ^(NSTask *t) {
        weakSelf.isRunning = NO;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf.delegate engineDidStop:weakSelf exitCode:t.terminationStatus]; });
    };

    NSError *launchError = nil;
    [self.task launchAndReturnError:&launchError];
    if (launchError) { if (error) *error = launchError; return NO; }
    self.isRunning = YES;
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf.delegate engineDidStart:weakSelf]; });
    return YES;
}

- (void)stop { if (self.task.isRunning) [self.task terminate]; }
- (void)forceStop { if (self.task.isRunning) [self.task interrupt]; }

@end
