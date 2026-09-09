//
//  VMNexusOpenMSXProcess.m
//  VMNexus
//
//  openMSX engine wrapper.
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusOpenMSXProcess.h"
#import "VMNexusEngineSelector.h"

@interface VMNexusOpenMSXProcess ()
@property (nonatomic, strong, readwrite) VMNexusVirtualMachine *virtualMachine;
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, strong) NSTask *task;
@end

@implementation VMNexusOpenMSXProcess

@synthesize delegate;

- (VMNexusEngineType)engineType { return VMNexusEngineTypeOpenMSX; }

- (instancetype)initWithVirtualMachine:(VMNexusVirtualMachine *)vm {
    self = [super init];
    if (self) { _virtualMachine = vm; _isRunning = NO; }
    return self;
}

- (BOOL)startWithError:(NSError **)error {
    NSString *binPath = [VMNexusEngineSelector executablePathForEngineType:VMNexusEngineTypeOpenMSX];
    if (!binPath) {
        if (error) *error = [NSError errorWithDomain:@"VMNexus" code:1001
            userInfo:@{NSLocalizedDescriptionKey: @"openMSX not found. Please install openMSX."}];
        return NO;
    }

    self.task = [[NSTask alloc] init];
    self.task.executableURL = [NSURL fileURLWithPath:binPath];
    NSMutableArray *args = [NSMutableArray array];
    if (self.virtualMachine.diskImagePath.length > 0) {
        [args addObjectsFromArray:@[@"-cart", self.virtualMachine.diskImagePath]];
    } else if (self.virtualMachine.floppyAPath.length > 0) {
        [args addObjectsFromArray:@[@"-diska", self.virtualMachine.floppyAPath]];
    }
    if (self.virtualMachine.machineType.length > 0) {
        NSString *model = [self.virtualMachine.machineType stringByReplacingOccurrencesOfString:@"msx-" withString:@""];
        [args addObjectsFromArray:@[@"-machine", model]];
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
