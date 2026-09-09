//
//  VMNexusBasiliskProcess.m
//  VMNexus
//
//  BasiliskII engine wrapper
//  Writes a temporary prefs file and launches BasiliskII with correct arguments.
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusBasiliskProcess.h"
#import "VMNexusEngineSelector.h"

// Classic Mac model → BasiliskII modelid mapping
// BasiliskII modelid: 4=Mac IIci, 5=Mac IIcx, 14=Mac Quadra 900, etc.
static NSDictionary<NSString *, NSNumber *> *basiliskModelIDs(void) {
    return @{
        @"MacII":        @(6),   // Mac II (68020)
        @"MacIIx":       @(7),   // Mac IIx (68030)
        @"MacIIcx":      @(8),   // Mac IIcx (68030)
        @"MacIIci":      @(9),   // Mac IIci (68030)
        @"MacIIfx":      @(13),  // Mac IIfx (68030)
        @"MacIIsi":      @(18),  // Mac IIsi (68030)
        @"MacIIvi":      @(19),  // Mac IIvi (68030)
        @"MacLC":        @(11),  // Mac LC (68020)
        @"MacLCII":      @(19),  // Mac LC II (68030)
        @"MacLCIII":     @(22),  // Mac LC III (68030)
        @"MacClassicII": @(23),  // Mac Classic II (68030)
        @"MacQuadra700": @(20),  // Quadra 700
        @"MacQuadra900": @(21),  // Quadra 900
        @"MacQuadra950": @(25),  // Quadra 950
        @"MacCentris610":@(28),  // Centris 610 (68040)
        @"MacCentris650":@(29),  // Centris 650 (68040)
        @"MacQuadra610": @(28),  // Quadra 610
        @"MacQuadra650": @(29),  // Quadra 650
        @"MacQuadra800": @(30),  // Quadra 800
        @"MacQuadra840AV":@(33), // Quadra 840AV
        @"MacPerforma630":@(34), // Performa 630 (68040)
    };
}

@interface VMNexusBasiliskProcess ()
@property (nonatomic, strong, readwrite) VMNexusVirtualMachine *virtualMachine;
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, strong) NSTask *task;
@property (nonatomic, strong) NSString *prefsFilePath;
@end

@implementation VMNexusBasiliskProcess

@synthesize delegate;

- (VMNexusEngineType)engineType { return VMNexusEngineTypeBasiliskII; }

- (instancetype)initWithVirtualMachine:(VMNexusVirtualMachine *)vm {
    self = [super init];
    if (self) {
        _virtualMachine = vm;
        _isRunning = NO;
    }
    return self;
}

- (BOOL)startWithError:(NSError **)error {
    NSString *binPath = [VMNexusEngineSelector executablePathForEngineType:VMNexusEngineTypeBasiliskII];
    if (!binPath) {
        if (error) {
            *error = [NSError errorWithDomain:@"VMNexus" code:1001
                userInfo:@{NSLocalizedDescriptionKey: @"BasiliskII not found. Please install BasiliskII.app."}];
        }
        return NO;
    }
    if (self.virtualMachine.romFilePath.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"VMNexus" code:1002
                userInfo:@{NSLocalizedDescriptionKey: @"ROM file required for Classic Mac emulation."}];
        }
        return NO;
    }

    NSString *prefsPath = [self writePrefsFile];
    if (!prefsPath) {
        if (error) {
            *error = [NSError errorWithDomain:@"VMNexus" code:1003
                userInfo:@{NSLocalizedDescriptionKey: @"Failed to write BasiliskII preferences."}];
        }
        return NO;
    }
    self.prefsFilePath = prefsPath;

    self.task = [[NSTask alloc] init];
    self.task.executableURL = [NSURL fileURLWithPath:binPath];
    self.task.arguments = @[@"--config", prefsPath];

    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    self.task.standardOutput = outPipe;
    self.task.standardError = errPipe;

    __weak typeof(self) weakSelf = self;
    outPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *fh) {
        NSData *data = fh.availableData;
        if (data.length > 0) {
            [weakSelf.delegate engine:weakSelf didOutputData:data];
        }
    };
    errPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *fh) {
        NSData *data = fh.availableData;
        if (data.length > 0) {
            [weakSelf.delegate engine:weakSelf didOutputError:data];
        }
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.delegate engineDidStart:weakSelf];
    });
    return YES;
}

- (NSString *)writePrefsFile {
    VMNexusVirtualMachine *vm = self.virtualMachine;
    NSMutableString *prefs = [NSMutableString string];

    // ROM
    [prefs appendFormat:@"rom %@\n", vm.romFilePath];

    // Memory: convert to bytes
    NSInteger memMB = [VMNexusVirtualMachine convertValue:vm.memoryValue
                                               fromUnit:vm.memoryUnit ?: @"MB"
                                                 toUnit:@"MB"];
    if (memMB < 4) memMB = 4;
    [prefs appendFormat:@"ramsize %ld\n", (long)(memMB * 1024 * 1024)];

    // Disk / boot drive
    if (vm.diskImagePath.length > 0) {
        [prefs appendFormat:@"disk %@\n", vm.diskImagePath];
    }
    // Extra disk images (CD-ROM / boot ISO)
    if (vm.cdromImagePath.length > 0) {
        [prefs appendFormat:@"cdrom %@\n", vm.cdromImagePath];
    }
    if (vm.bootISOPath.length > 0) {
        [prefs appendFormat:@"cdrom %@\n", vm.bootISOPath];
    }
    // Floppy
    if (vm.floppyAPath.length > 0) {
        [prefs appendFormat:@"floppy %@\n", vm.floppyAPath];
    }
    if (vm.floppyBPath.length > 0) {
        [prefs appendFormat:@"floppy %@\n", vm.floppyBPath];
    }

    // Model ID
    NSString *model = vm.classicMacModel ?: @"MacIIci";
    NSNumber *modelID = basiliskModelIDs()[model];
    [prefs appendFormat:@"modelid %ld\n", modelID ? modelID.longValue : 9L];

    // CPU: BasiliskII 0=68000 1=68010 2=68020 3=68030 4=68040
    [prefs appendFormat:@"cpu 3\n"]; // 68030 default for Mac II family

    // Screen
    [prefs appendFormat:@"screen win/%ld/%ld/8\n", 800L, 600L];

    // Network: slirp if user requested, otherwise disabled
    if ([vm.networkMode isEqualToString:@"user"] || [vm.networkMode isEqualToString:@"slirp"]) {
        [prefs appendFormat:@"nonet false\n"];
        [prefs appendFormat:@"ether slirp\n"];
    } else {
        [prefs appendFormat:@"nonet true\n"];
    }

    // Audio
    if (vm.enableAudio) {
        [prefs appendFormat:@"sound true\n"];
    }

    // Write to temp file in VM bundle
    NSString *dir = vm.vmBundlePath ?: NSTemporaryDirectory();
    NSString *path = [dir stringByAppendingPathComponent:@"basilisk_prefs"];
    NSError *err = nil;
    [prefs writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err];
    return err ? nil : path;
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
