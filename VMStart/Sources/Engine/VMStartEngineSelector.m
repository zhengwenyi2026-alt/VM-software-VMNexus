//
//  VMStartEngineSelector.m
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMStartEngineSelector.h"
#import "VMStartQEMUProcess.h"
#import "VMStartBasiliskProcess.h"
#import "VMStartMiniVMacProcess.h"
#import "VMStartSheepShaverProcess.h"
#import "VMStartDOSBoxProcess.h"
#import "VMStartDOSBoxXProcess.h"
#import "VMStartPCemProcess.h"
#import "VMStart86BoxProcess.h"
#import "VMStartVICEProcess.h"
#import "VMStartFSUAEProcess.h"
#import "VMStartHatariProcess.h"
#import "VMStartOpenMSXProcess.h"
#import "VMStartFuseProcess.h"
#import "VMStartScummVMProcess.h"
#import "VMStartMednafenProcess.h"
#import "VMStartARAnyMProcess.h"

#pragma mark - Machine type → engine routing

static NSDictionary<NSString *, NSNumber *> *EnginePrefixMap(void) {
    static NSDictionary *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            // QEMU fallback for explicit qemu-prefixed machines
            @"qemu":         @(VMStartEngineTypeQEMU),
            // Classic 68k Mac (early System 1-6)
            @"mac128k":      @(VMStartEngineTypeMiniVMac),
            @"mac512k":      @(VMStartEngineTypeMiniVMac),
            @"macplus":      @(VMStartEngineTypeMiniVMac),
            @"macse":        @(VMStartEngineTypeMiniVMac),
            @"macclassic":   @(VMStartEngineTypeMiniVMac),
            // Mac II family
            @"macii":        @(VMStartEngineTypeBasiliskII),
            @"maclc":        @(VMStartEngineTypeBasiliskII),
            @"macquadra":    @(VMStartEngineTypeBasiliskII),
            @"maccentris":   @(VMStartEngineTypeBasiliskII),
            @"macperforma":  @(VMStartEngineTypeBasiliskII),
            // PowerPC Mac
            @"ppc":           @(VMStartEngineTypeSheepShaver),
            @"powermac":      @(VMStartEngineTypeSheepShaver),
            @"g3":            @(VMStartEngineTypeSheepShaver),
            @"g4":            @(VMStartEngineTypeSheepShaver),
            @"sheepshaver":   @(VMStartEngineTypeSheepShaver),
            // x86 PC emulators
            @"dosbox-x":      @(VMStartEngineTypeDOSBoxX),
            @"dosbox":        @(VMStartEngineTypeDOSBox),
            @"pcem":          @(VMStartEngineTypePCem),
            @"86box":         @(VMStartEngineType86Box),
            // Commodore 8-bit
            @"c64":           @(VMStartEngineTypeVICE),
            @"c128":          @(VMStartEngineTypeVICE),
            @"pet":           @(VMStartEngineTypeVICE),
            @"vic20":         @(VMStartEngineTypeVICE),
            // Amiga
            @"amiga":         @(VMStartEngineTypeFSUAE),
            // Atari
            @"atarist":       @(VMStartEngineTypeHatari),
            @"atariste":      @(VMStartEngineTypeHatari),
            @"ataritt":       @(VMStartEngineTypeHatari),
            @"atarifalcon":   @(VMStartEngineTypeHatari),
            @"aranym":        @(VMStartEngineTypeARAnyM),
            // MSX / Spectrum
            @"msx":           @(VMStartEngineTypeOpenMSX),
            @"spectrum":      @(VMStartEngineTypeFuse),
            @"zx":            @(VMStartEngineTypeFuse),
            // Others
            @"scumm":         @(VMStartEngineTypeScummVM),
            @"scummvm":       @(VMStartEngineTypeScummVM),
            @"mednafen":      @(VMStartEngineTypeMednafen),
        };
    });
    return map;
}

#pragma mark - Executable discovery

static NSString *FirstExistingExecutable(NSArray<NSString *> *candidates) {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in candidates) {
        if ([fm fileExistsAtPath:p] && [fm isExecutableFileAtPath:p]) return p;
    }
    return nil;
}

static NSString *FindInApplications(NSString *bundleNameContains, NSString *binaryName) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *apps = [fm contentsOfDirectoryAtPath:@"/Applications" error:nil];
    for (NSString *app in apps) {
        if ([app.lowercaseString containsString:bundleNameContains.lowercaseString]) {
            if (binaryName.length > 0) {
                NSString *bin = [NSString stringWithFormat:@"/Applications/%@/Contents/MacOS/%@", app, binaryName];
                if ([fm fileExistsAtPath:bin]) return bin;
            }
            // Otherwise guess first binary in MacOS
            NSString *macosDir = [NSString stringWithFormat:@"/Applications/%@/Contents/MacOS", app];
            NSArray *bins = [fm contentsOfDirectoryAtPath:macosDir error:nil];
            if (bins.firstObject) {
                return [macosDir stringByAppendingPathComponent:bins.firstObject];
            }
        }
    }
    return nil;
}

static NSString *FindExecutableWithAppFallback(NSString *binaryName, NSString *bundleHint) {
    NSArray *paths = @[
        [NSString stringWithFormat:@"/opt/homebrew/bin/%@", binaryName],
        [NSString stringWithFormat:@"/usr/local/bin/%@", binaryName],
        [NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), @"bin"],
    ];
    NSString *found = FirstExistingExecutable(paths);
    if (found) return found;
    return FindInApplications(bundleHint, binaryName);
}

#pragma mark - Implementation

@implementation VMStartEngineSelector

+ (VMStartEngineType)engineTypeForMachine:(NSString *)machineType {
    NSString *lower = machineType.lowercaseString;
    if (lower.length == 0) return VMStartEngineTypeQEMU;

    NSDictionary *map = EnginePrefixMap();
    NSArray *sortedPrefixes = [[map allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [@(b.length) compare:@(a.length)]; // longest first (dosbox-x before dosbox)
    }];

    for (NSString *prefix in sortedPrefixes) {
        if ([lower hasPrefix:prefix]) {
            return ((NSNumber *)map[prefix]).integerValue;
        }
    }
    return VMStartEngineTypeQEMU;
}

+ (VMStartEngineType)engineTypeForVM:(VMStartVirtualMachine *)vm {
    return [self engineTypeForMachine:vm.machineType];
}

+ (id<VMStartEngine>)engineForVM:(VMStartVirtualMachine *)vm {
    VMStartEngineType type = [self engineTypeForVM:vm];
    switch (type) {
        case VMStartEngineTypeMiniVMac:    return [[VMStartMiniVMacProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeBasiliskII:  return [[VMStartBasiliskProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeSheepShaver: return [[VMStartSheepShaverProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeDOSBox:      return [[VMStartDOSBoxProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeDOSBoxX:     return [[VMStartDOSBoxXProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypePCem:        return [[VMStartPCemProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineType86Box:       return [[VMStart86BoxProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeVICE:        return [[VMStartVICEProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeFSUAE:       return [[VMStartFSUAEProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeHatari:      return [[VMStartHatariProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeOpenMSX:     return [[VMStartOpenMSXProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeFuse:        return [[VMStartFuseProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeScummVM:     return [[VMStartScummVMProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeMednafen:    return [[VMStartMednafenProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeARAnyM:      return [[VMStartARAnyMProcess alloc] initWithVirtualMachine:vm];
        case VMStartEngineTypeQEMU:
        default:                         return (id<VMStartEngine>)[[VMStartQEMUProcess alloc] initWithVirtualMachine:vm];
    }
}

+ (NSString *)nameForEngineType:(VMStartEngineType)type {
    switch (type) {
        case VMStartEngineTypeQEMU:       return @"QEMU";
        case VMStartEngineTypeBasiliskII: return @"BasiliskII";
        case VMStartEngineTypeMiniVMac:   return @"Mini vMac";
        case VMStartEngineTypeSheepShaver:return @"SheepShaver";
        case VMStartEngineTypeDOSBox:     return @"DOSBox";
        case VMStartEngineTypeDOSBoxX:    return @"DOSBox-X";
        case VMStartEngineTypePCem:       return @"PCem";
        case VMStartEngineType86Box:      return @"86Box";
        case VMStartEngineTypeVICE:       return @"VICE";
        case VMStartEngineTypeFSUAE:      return @"FS-UAE";
        case VMStartEngineTypeHatari:     return @"Hatari";
        case VMStartEngineTypeOpenMSX:    return @"openMSX";
        case VMStartEngineTypeFuse:       return @"Fuse";
        case VMStartEngineTypeScummVM:    return @"ScummVM";
        case VMStartEngineTypeMednafen:   return @"Mednafen";
        case VMStartEngineTypeARAnyM:     return @"ARAnyM";
        default:                        return @"Unknown";
    }
}

+ (nullable NSString *)executablePathForEngineType:(VMStartEngineType)type {
    switch (type) {
        case VMStartEngineTypeQEMU: {
            // Handled by VMStartQEMUProcess version detection; return a generic marker
            return @"/usr/local/bin/qemu-system-x86_64";
        }
        case VMStartEngineTypeBasiliskII: {
            NSArray *paths = @[
                @"/Applications/BasiliskII.app/Contents/MacOS/BasiliskII",
                @"/Applications/Basilisk II.app/Contents/MacOS/BasiliskII",
                @"/opt/homebrew/bin/BasiliskII",
                @"/usr/local/bin/BasiliskII",
            ];
            NSString *found = FirstExistingExecutable(paths);
            return found ?: FindInApplications(@"Basilisk", @"BasiliskII");
        }
        case VMStartEngineTypeMiniVMac: {
            NSArray *paths = @[
                @"/Applications/Mini vMac.app/Contents/MacOS/minivmac",
                @"/Applications/Mini vMac.app/Contents/MacOS/Mini vMac",
                @"/opt/homebrew/bin/minivmac",
                @"/usr/local/bin/minivmac",
            ];
            NSString *found = FirstExistingExecutable(paths);
            return found ?: FindInApplications(@"Mini vMac", nil);
        }
        case VMStartEngineTypeSheepShaver: {
            return FindExecutableWithAppFallback(@"SheepShaver", @"SheepShaver");
        }
        case VMStartEngineTypeDOSBox: {
            return FindExecutableWithAppFallback(@"dosbox", @"DOSBox");
        }
        case VMStartEngineTypeDOSBoxX: {
            return FindExecutableWithAppFallback(@"dosbox-x", @"DOSBox-X");
        }
        case VMStartEngineTypePCem: {
            return FindExecutableWithAppFallback(@"pcem", @"PCem");
        }
        case VMStartEngineType86Box: {
            return FindExecutableWithAppFallback(@"86Box", @"86Box");
        }
        case VMStartEngineTypeVICE: {
            NSArray *paths = @[
                @"/Applications/VICE.app/Contents/MacOS/x64sc",
                @"/opt/homebrew/bin/x64sc",
                @"/usr/local/bin/x64sc",
            ];
            NSString *found = FirstExistingExecutable(paths);
            return found ?: FindInApplications(@"VICE", @"x64sc");
        }
        case VMStartEngineTypeFSUAE: {
            return FindExecutableWithAppFallback(@"fs-uae", @"FS-UAE");
        }
        case VMStartEngineTypeHatari: {
            return FindExecutableWithAppFallback(@"hatari", @"Hatari");
        }
        case VMStartEngineTypeOpenMSX: {
            return FindExecutableWithAppFallback(@"openmsx", @"OpenMSX");
        }
        case VMStartEngineTypeFuse: {
            return FindExecutableWithAppFallback(@"fuse", @"Fuse");
        }
        case VMStartEngineTypeScummVM: {
            return FindExecutableWithAppFallback(@"scummvm", @"ScummVM");
        }
        case VMStartEngineTypeMednafen: {
            return FindExecutableWithAppFallback(@"mednafen", @"Mednafen");
        }
        case VMStartEngineTypeARAnyM: {
            return FindExecutableWithAppFallback(@"aranym", @"ARAnyM");
        }
        default: return nil;
    }
}

+ (nullable NSString *)executablePathForMachineType:(NSString *)machineType {
    return [self executablePathForEngineType:[self engineTypeForMachine:machineType]];
}

@end
