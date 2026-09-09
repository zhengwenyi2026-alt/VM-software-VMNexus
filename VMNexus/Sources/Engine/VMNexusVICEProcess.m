//
//  VMNexusVICEProcess.m
//  VMNexus
//
//  VICE Commodore 8-bit engine wrapper.
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusVICEProcess.h"
#import "VMNexusEngineSelector.h"

@interface VMNexusVICEProcess ()
@property (nonatomic, strong, readwrite) VMNexusVirtualMachine *virtualMachine;
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, strong) NSTask *task;
@end

@implementation VMNexusVICEProcess

@synthesize delegate;

- (VMNexusEngineType)engineType { return VMNexusEngineTypeVICE; }

- (instancetype)initWithVirtualMachine:(VMNexusVirtualMachine *)vm {
    self = [super init];
    if (self) { _virtualMachine = vm; _isRunning = NO; }
    return self;
}

- (NSString *)viceBinaryForMachine:(NSString *)machine {
    NSString *lower = machine.lowercaseString;
    if ([lower hasPrefix:@"c128"]) return @"x128";
    if ([lower hasPrefix:@"pet"])  return @"xpet";
    if ([lower hasPrefix:@"vic20"]) return @"xvic";
    return @"x64sc";
}

- (BOOL)startWithError:(NSError **)error {
    NSString *binary = [self viceBinaryForMachine:self.virtualMachine.machineType];
    NSString *binPath = [VMNexusEngineSelector executablePathForEngineType:VMNexusEngineTypeVICE];
    // binPath may point to x64sc; rebuild with correct binary name
    if (binPath) binPath = [[binPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:binary];
    if (!binPath || ![[NSFileManager defaultManager] fileExistsAtPath:binPath]) {
        if (error) *error = [NSError errorWithDomain:@"VMNexus" code:1001
            userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"VICE binary %@ not found.", binary]}];
        return NO;
    }

    self.task = [[NSTask alloc] init];
    self.task.executableURL = [NSURL fileURLWithPath:binPath];
    NSMutableArray *args = [NSMutableArray array];
    if (self.virtualMachine.floppyAPath.length > 0) {
        [args addObjectsFromArray:@[@"-8", self.virtualMachine.floppyAPath]];
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
