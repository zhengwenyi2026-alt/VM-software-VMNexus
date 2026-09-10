//
//  VMStartMednafenProcess.m
//  VMStart
//
//  Mednafen multi-system engine wrapper.
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMStartMednafenProcess.h"
#import "VMStartEngineSelector.h"

@interface VMStartMednafenProcess ()
@property (nonatomic, strong, readwrite) VMStartVirtualMachine *virtualMachine;
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, strong) NSTask *task;
@end

@implementation VMStartMednafenProcess

@synthesize delegate;

- (VMStartEngineType)engineType { return VMStartEngineTypeMednafen; }

- (instancetype)initWithVirtualMachine:(VMStartVirtualMachine *)vm {
    self = [super init];
    if (self) { _virtualMachine = vm; _isRunning = NO; }
    return self;
}

- (NSString *)mednafenCoreForMachine:(NSString *)machine {
    NSString *lower = machine.lowercaseString;
    if ([lower containsString:@"psx"])  return @"psx";
    if ([lower containsString:@"ss"])   return @"ss";
    if ([lower containsString:@"pce"])  return @"pce";
    if ([lower containsString:@"gba"])  return @"gba";
    if ([lower containsString:@"gb"])   return @"gb";
    if ([lower containsString:@"nes"])  return @"nes";
    if ([lower containsString:@"snes"]) return @"snes";
    return @"psx";
}

- (BOOL)startWithError:(NSError **)error {
    NSString *binPath = [VMStartEngineSelector executablePathForEngineType:VMStartEngineTypeMednafen];
    if (!binPath) {
        if (error) *error = [NSError errorWithDomain:@"VMStart" code:1001
            userInfo:@{NSLocalizedDescriptionKey: @"Mednafen not found. Please install Mednafen."}];
        return NO;
    }

    self.task = [[NSTask alloc] init];
    self.task.executableURL = [NSURL fileURLWithPath:binPath];
    NSMutableArray *args = [NSMutableArray array];
    if (self.virtualMachine.diskImagePath.length > 0) {
        [args addObject:[NSString stringWithFormat:@"-%@.new", [self mednafenCoreForMachine:self.virtualMachine.machineType]]];
        [args addObject:self.virtualMachine.diskImagePath];
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
