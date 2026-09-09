//
//  VMNexusSheepShaverProcess.m
//  VMNexus
//
//  SheepShaver PowerPC Mac engine wrapper.
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusSheepShaverProcess.h"
#import "VMNexusEngineSelector.h"

@interface VMNexusSheepShaverProcess ()
@property (nonatomic, strong, readwrite) VMNexusVirtualMachine *virtualMachine;
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, strong) NSTask *task;
@end

@implementation VMNexusSheepShaverProcess

@synthesize delegate;

- (VMNexusEngineType)engineType { return VMNexusEngineTypeSheepShaver; }

- (instancetype)initWithVirtualMachine:(VMNexusVirtualMachine *)vm {
    self = [super init];
    if (self) {
        _virtualMachine = vm;
        _isRunning = NO;
    }
    return self;
}

- (BOOL)startWithError:(NSError **)error {
    NSString *binPath = [VMNexusEngineSelector executablePathForEngineType:VMNexusEngineTypeSheepShaver];
    if (!binPath) {
        if (error) *error = [NSError errorWithDomain:@"VMNexus" code:1001
            userInfo:@{NSLocalizedDescriptionKey: @"SheepShaver not found. Please install SheepShaver.app."}];
        return NO;
    }
    if (self.virtualMachine.romFilePath.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"VMNexus" code:1002
            userInfo:@{NSLocalizedDescriptionKey: @"ROM file required for SheepShaver."}];
        return NO;
    }

    self.task = [[NSTask alloc] init];
    self.task.executableURL = [NSURL fileURLWithPath:binPath];
    self.task.arguments = @[@"--rom", self.virtualMachine.romFilePath ?: @""];

    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    self.task.standardOutput = outPipe;
    self.task.standardError = errPipe;

    __weak typeof(self) weakSelf = self;
    outPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *fh) {
        NSData *data = fh.availableData;
        if (data.length > 0) [weakSelf.delegate engine:weakSelf didOutputData:data];
    };
    errPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *fh) {
        NSData *data = fh.availableData;
        if (data.length > 0) [weakSelf.delegate engine:weakSelf didOutputError:data];
    };
    self.task.terminationHandler = ^(NSTask *t) {
        weakSelf.isRunning = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.delegate engineDidStop:weakSelf exitCode:t.terminationStatus];
        });
    };

    NSError *launchError = nil;
    [self.task launchAndReturnError:&launchError];
    if (launchError) {
        if (error) *error = launchError;
        return NO;
    }
    self.isRunning = YES;
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf.delegate engineDidStart:weakSelf]; });
    return YES;
}

- (void)stop { if (self.task.isRunning) [self.task terminate]; }
- (void)forceStop { if (self.task.isRunning) [self.task interrupt]; }

@end
