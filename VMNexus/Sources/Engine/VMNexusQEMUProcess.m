//
//  VMNexusQEMUProcess.m
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusQEMUProcess.h"

@interface VMNexusQEMUProcess ()
@property (nonatomic, strong, readwrite) VMNexusVirtualMachine *virtualMachine;
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, assign, readwrite) NSInteger processIdentifier;
@property (nonatomic, strong, readwrite) NSMutableString *mutableLogOutput;
@property (nonatomic, strong) NSTask *qemuTask;
@property (nonatomic, strong) NSPipe *stdoutPipe;
@property (nonatomic, strong) NSPipe *stderrPipe;
@property (nonatomic, strong) NSPipe *monitorPipe;
@end

@implementation VMNexusQEMUProcess

- (instancetype)initWithVirtualMachine:(VMNexusVirtualMachine *)vm {
    self = [super init];
    if (self) {
        _virtualMachine = vm;
        _isRunning = NO;
        _mutableLogOutput = [NSMutableString string];
    }
    return self;
}

- (NSString *)logOutput {
    return [self.mutableLogOutput copy];
}

- (BOOL)startWithError:(NSError **)error {
    if (self.isRunning) {
        if (error) {
            *error = [NSError errorWithDomain:@"VMNexus" code:1 userInfo:@{NSLocalizedDescriptionKey: @"VM is already running"}];
        }
        return NO;
    }
    NSString *binaryPath = [self.virtualMachine qemuBinaryPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:binaryPath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"VMNexus" code:2
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"QEMU binary not found: %@", binaryPath]}];
        }
        return NO;
    }
    self.qemuTask = [[NSTask alloc] init];
    self.qemuTask.executableURL = [NSURL fileURLWithPath:binaryPath];
    self.qemuTask.currentDirectoryURL = [NSURL fileURLWithPath:self.virtualMachine.vmBundlePath ?: NSTemporaryDirectory()];
    NSArray *args = [self.virtualMachine buildQEMUArguments];
    self.qemuTask.arguments = args;
    self.stdoutPipe = [NSPipe pipe];
    self.stderrPipe = [NSPipe pipe];
    self.qemuTask.standardOutput = self.stdoutPipe;
    self.qemuTask.standardError = self.stderrPipe;
    [[self.stdoutPipe fileHandleForReading] readInBackgroundAndNotify];
    [[self.stderrPipe fileHandleForReading] readInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleOutput:)
                                                 name:NSFileHandleReadCompletionNotification object:[self.stdoutPipe fileHandleForReading]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleError:)
                                                 name:NSFileHandleReadCompletionNotification object:[self.stderrPipe fileHandleForReading]];
    self.qemuTask.terminationHandler = ^(NSTask *task) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isRunning = NO;
            self.virtualMachine.status = VMNexusStatusStopped;
            [self.delegate qemuProcessDidStop:self exitCode:task.terminationStatus];
        });
    };
    @try {
        [self.qemuTask launch];
        self.isRunning = YES;
        self.processIdentifier = self.qemuTask.processIdentifier;
        self.virtualMachine.status = VMNexusStatusRunning;
        self.virtualMachine.lastUsedAt = [NSDate date];
        [self.virtualMachine saveToBundle];
        [self.delegate qemuProcessDidStart:self];
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"VMNexus" code:3
                                     userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Failed to launch QEMU"}];
        }
        [self.delegate qemuProcess:self didFailWithError:*error];
        return NO;
    }
}

- (void)stop {
    if (!self.isRunning || !self.qemuTask) return;
    self.virtualMachine.status = VMNexusStatusStopping;
    [self sendMonitorCommand:@"system_powerdown" completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.isRunning) {
            [self forceStop];
        }
    });
}

- (void)forceStop {
    if (!self.isRunning || !self.qemuTask) return;
    [self.qemuTask terminate];
    self.isRunning = NO;
    self.virtualMachine.status = VMNexusStatusStopped;
}

- (void)pause {
    if (!self.isRunning) return;
    [self sendMonitorCommand:@"stop" completion:nil];
    self.virtualMachine.status = VMNexusStatusPaused;
}

- (void)resume {
    if (!self.isRunning) return;
    [self sendMonitorCommand:@"cont" completion:nil];
    self.virtualMachine.status = VMNexusStatusRunning;
}

- (void)sendMonitorCommand:(NSString *)command completion:(void (^)(NSString *))completion {
    if (!self.isRunning || !self.qemuTask) return;
    NSData *data = [[command stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    [[[self.qemuTask standardInput] fileHandleForWriting] writeData:data];
    if (completion) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            completion(@"Command sent");
        });
    }
}

- (BOOL)captureScreenshotToPath:(NSString *)path {
    if (!self.isRunning) return NO;
    [self sendMonitorCommand:[NSString stringWithFormat:@"screendump %@", path] completion:nil];
    return YES;
}

- (void)handleOutput:(NSNotification *)notification {
    NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if (data.length == 0) return;
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (str) {
        [self.mutableLogOutput appendString:str];
        [self.delegate qemuProcess:self didOutputData:data];
    }
    [[notification object] readInBackgroundAndNotify];
}

- (void)handleError:(NSNotification *)notification {
    NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if (data.length == 0) return;
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (str) {
        [self.mutableLogOutput appendString:str];
        [self.delegate qemuProcess:self didOutputError:data];
    }
    [[notification object] readInBackgroundAndNotify];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.isRunning) {
        [self.qemuTask terminate];
    }
}

@end
