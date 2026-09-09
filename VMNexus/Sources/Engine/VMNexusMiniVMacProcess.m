//
//  VMNexusMiniVMacProcess.m
//  VMNexus
//
//  Mini vMac engine wrapper.
//  Mini vMac is a GUI app — we launch it via NSWorkspace/NSTask, passing
//  the ROM file via the -r flag and disk images via drag-style arguments.
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusMiniVMacProcess.h"
#import "VMNexusEngineSelector.h"
#import <AppKit/AppKit.h>

@interface VMNexusMiniVMacProcess ()
@property (nonatomic, strong, readwrite) VMNexusVirtualMachine *virtualMachine;
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, strong) NSTask *task;
@end

@implementation VMNexusMiniVMacProcess

@synthesize delegate;

- (VMNexusEngineType)engineType { return VMNexusEngineTypeMiniVMac; }

- (instancetype)initWithVirtualMachine:(VMNexusVirtualMachine *)vm {
    self = [super init];
    if (self) {
        _virtualMachine = vm;
        _isRunning = NO;
    }
    return self;
}

- (BOOL)startWithError:(NSError **)error {
    // Try command-line binary first, fall back to opening the .app via NSWorkspace
    NSString *binPath = [VMNexusEngineSelector executablePathForEngineType:VMNexusEngineTypeMiniVMac];

    if (self.virtualMachine.romFilePath.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"VMNexus" code:2002
                userInfo:@{NSLocalizedDescriptionKey: @"ROM file required for Classic Mac 128K/Plus/SE emulation."}];
        }
        return NO;
    }

    if (binPath) {
        return [self startWithBinary:binPath error:error];
    } else {
        // Try to open Mini vMac.app via NSWorkspace with ROM + disk as arguments
        return [self startViaWorkspaceWithError:error];
    }
}

- (BOOL)startWithBinary:(NSString *)binPath error:(NSError **)error {
    VMNexusVirtualMachine *vm = self.virtualMachine;
    NSMutableArray *args = [NSMutableArray array];

    // ROM file
    [args addObject:@"-r"];
    [args addObject:vm.romFilePath];

    // Disk images passed as positional arguments
    if (vm.diskImagePath.length > 0) {
        [args addObject:vm.diskImagePath];
    }
    if (vm.floppyAPath.length > 0) {
        [args addObject:vm.floppyAPath];
    }
    if (vm.floppyBPath.length > 0) {
        [args addObject:vm.floppyBPath];
    }
    if (vm.cdromImagePath.length > 0) {
        [args addObject:vm.cdromImagePath];
    }
    if (vm.bootISOPath.length > 0) {
        [args addObject:vm.bootISOPath];
    }

    self.task = [[NSTask alloc] init];
    self.task.executableURL = [NSURL fileURLWithPath:binPath];
    self.task.arguments = args;

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

    NSError *launchErr = nil;
    [self.task launchAndReturnError:&launchErr];
    if (launchErr) {
        if (error) *error = launchErr;
        return NO;
    }
    self.isRunning = YES;
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_main_queue(), ^{ [ws.delegate engineDidStart:ws]; });
    return YES;
}

- (BOOL)startViaWorkspaceWithError:(NSError **)error {
    // Search for Mini vMac.app in /Applications
    NSString *appPath = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *apps = [fm contentsOfDirectoryAtPath:@"/Applications" error:nil];
    for (NSString *app in apps) {
        if ([app.lowercaseString containsString:@"mini"] && [app.lowercaseString containsString:@"vmac"]) {
            appPath = [@"/Applications" stringByAppendingPathComponent:app];
            break;
        }
    }
    if (!appPath) {
        if (error) {
            *error = [NSError errorWithDomain:@"VMNexus" code:2001
                userInfo:@{NSLocalizedDescriptionKey:
                    @"Mini vMac not found. Install via: brew install --cask mini-vmac"}];
        }
        return NO;
    }

    VMNexusVirtualMachine *vm = self.virtualMachine;
    NSMutableArray<NSURL *> *fileURLs = [NSMutableArray array];
    // ROM must be copied into the app bundle directory or passed via open
    if (vm.romFilePath.length > 0) [fileURLs addObject:[NSURL fileURLWithPath:vm.romFilePath]];
    if (vm.diskImagePath.length > 0) [fileURLs addObject:[NSURL fileURLWithPath:vm.diskImagePath]];
    if (vm.floppyAPath.length > 0) [fileURLs addObject:[NSURL fileURLWithPath:vm.floppyAPath]];
    if (vm.floppyBPath.length > 0) [fileURLs addObject:[NSURL fileURLWithPath:vm.floppyBPath]];

    NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
    config.activates = YES;
    [[NSWorkspace sharedWorkspace] openURLs:fileURLs
                       withApplicationAtURL:[NSURL fileURLWithPath:appPath]
                              configuration:config
                          completionHandler:^(NSRunningApplication *app, NSError *err) {
        if (err) {
            [self.delegate engine:self didFailWithError:err];
        } else {
            self.isRunning = YES;
            [self.delegate engineDidStart:self];
            // Monitor process termination via KVO on terminationDate
            __weak typeof(self) weakSelf = self;
            NSRunningApplication *runApp = app;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                while (!runApp.terminated) {
                    [NSThread sleepForTimeInterval:0.5];
                }
                weakSelf.isRunning = NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.delegate engineDidStop:weakSelf exitCode:0];
                });
            });
        }
    }];
    return YES;
}

- (void)stop {
    if (self.task.isRunning) {
        [self.task terminate];
    }
}

- (void)forceStop {
    if (self.task.isRunning) {
        [self.task interrupt];
    }
}

@end
