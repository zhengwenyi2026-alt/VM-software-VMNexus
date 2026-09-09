//
//  VMNexusEngineSelector.m
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusEngineSelector.h"
#import "VMNexusQEMUProcess.h"
#import "VMNexusBasiliskProcess.h"
#import "VMNexusMiniVMacProcess.h"
#import "VMNexusSheepShaverProcess.h"
#import "VMNexusDOSBoxProcess.h"
#import "VMNexusDOSBoxXProcess.h"
#import "VMNexusPCemProcess.h"
#import "VMNexus86BoxProcess.h"
#import "VMNexusVICEProcess.h"
#import "VMNexusFSUAEProcess.h"
#import "VMNexusHatariProcess.h"
#import "VMNexusOpenMSXProcess.h"
#import "VMNexusFuseProcess.h"
#import "VMNexusScummVMProcess.h"
#import "VMNexusMednafenProcess.h"
#import "VMNexusARAnyMProcess.h"

#pragma mark - Machine type → engine routing

static NSDictionary<NSString *, NSNumber *> *EnginePrefixMap(void) {
    static NSDictionary *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            // QEMU fallback for explicit qemu-prefixed machines
            @"qemu":         @(VMNexusEngineTypeQEMU),
            // Classic 68k Mac (early System 1-6)
            @"mac128k":      @(VMNexusEngineTypeMiniVMac),
            @"mac512k":      @(VMNexusEngineTypeMiniVMac),
            @"macplus":      @(VMNexusEngineTypeMiniVMac),
            @"macse":        @(VMNexusEngineTypeMiniVMac),
            @"macclassic":   @(VMNexusEngineTypeMiniVMac),
            // Mac II family
            @"macii":        @(VMNexusEngineTypeBasiliskII),
            @"maclc":        @(VMNexusEngineTypeBasiliskII),
            @"macquadra":    @(VMNexusEngineTypeBasiliskII),
            @"maccentris":   @(VMNexusEngineTypeBasiliskII),
            @"macperforma":  @(VMNexusEngineTypeBasiliskII),
            // PowerPC Mac
            @"ppc":           @(VMNexusEngineTypeSheepShaver),
            @"powermac":      @(VMNexusEngineTypeSheepShaver),
            @"g3":            @(VMNexusEngineTypeSheepShaver),
            @"g4":            @(VMNexusEngineTypeSheepShaver),
            @"sheepshaver":   @(VMNexusEngineTypeSheepShaver),
            // x86 PC emulators
            @"dosbox-x":      @(VMNexusEngineTypeDOSBoxX),
            @"dosbox":        @(VMNexusEngineTypeDOSBox),
            @"pcem":          @(VMNexusEngineTypePCem),
            @"86box":         @(VMNexusEngineType86Box),
            // Commodore 8-bit
            @"c64":           @(VMNexusEngineTypeVICE),
            @"c128":          @(VMNexusEngineTypeVICE),
            @"pet":           @(VMNexusEngineTypeVICE),
            @"vic20":         @(VMNexusEngineTypeVICE),
            // Amiga
            @"amiga":         @(VMNexusEngineTypeFSUAE),
            // Atari
            @"atarist":       @(VMNexusEngineTypeHatari),
            @"atariste":      @(VMNexusEngineTypeHatari),
            @"ataritt":       @(VMNexusEngineTypeHatari),
            @"atarifalcon":   @(VMNexusEngineTypeHatari),
            @"aranym":        @(VMNexusEngineTypeARAnyM),
            // MSX / Spectrum
            @"msx":           @(VMNexusEngineTypeOpenMSX),
            @"spectrum":      @(VMNexusEngineTypeFuse),
            @"zx":            @(VMNexusEngineTypeFuse),
            // Others
            @"scumm":         @(VMNexusEngineTypeScummVM),
            @"scummvm":       @(VMNexusEngineTypeScummVM),
            @"mednafen":      @(VMNexusEngineTypeMednafen),
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

@implementation VMNexusEngineSelector

+ (VMNexusEngineType)engineTypeForMachine:(NSString *)machineType {
    NSString *lower = machineType.lowercaseString;
    if (lower.length == 0) return VMNexusEngineTypeQEMU;

    NSDictionary *map = EnginePrefixMap();
    NSArray *sortedPrefixes = [[map allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [@(b.length) compare:@(a.length)]; // longest first (dosbox-x before dosbox)
    }];

    for (NSString *prefix in sortedPrefixes) {
        if ([lower hasPrefix:prefix]) {
            return ((NSNumber *)map[prefix]).integerValue;
        }
    }
    return VMNexusEngineTypeQEMU;
}

+ (VMNexusEngineType)engineTypeForVM:(VMNexusVirtualMachine *)vm {
    return [self engineTypeForMachine:vm.machineType];
}

+ (id<VMNexusEngine>)engineForVM:(VMNexusVirtualMachine *)vm {
    VMNexusEngineType type = [self engineTypeForVM:vm];
    switch (type) {
        case VMNexusEngineTypeMiniVMac:    return [[VMNexusMiniVMacProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeBasiliskII:  return [[VMNexusBasiliskProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeSheepShaver: return [[VMNexusSheepShaverProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeDOSBox:      return [[VMNexusDOSBoxProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeDOSBoxX:     return [[VMNexusDOSBoxXProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypePCem:        return [[VMNexusPCemProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineType86Box:       return [[VMNexus86BoxProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeVICE:        return [[VMNexusVICEProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeFSUAE:       return [[VMNexusFSUAEProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeHatari:      return [[VMNexusHatariProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeOpenMSX:     return [[VMNexusOpenMSXProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeFuse:        return [[VMNexusFuseProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeScummVM:     return [[VMNexusScummVMProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeMednafen:    return [[VMNexusMednafenProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeARAnyM:      return [[VMNexusARAnyMProcess alloc] initWithVirtualMachine:vm];
        case VMNexusEngineTypeQEMU:
        default:                         return (id<VMNexusEngine>)[[VMNexusQEMUProcess alloc] initWithVirtualMachine:vm];
    }
}

+ (NSString *)nameForEngineType:(VMNexusEngineType)type {
    switch (type) {
        case VMNexusEngineTypeQEMU:       return @"QEMU";
        case VMNexusEngineTypeBasiliskII: return @"BasiliskII";
        case VMNexusEngineTypeMiniVMac:   return @"Mini vMac";
        case VMNexusEngineTypeSheepShaver:return @"SheepShaver";
        case VMNexusEngineTypeDOSBox:     return @"DOSBox";
        case VMNexusEngineTypeDOSBoxX:    return @"DOSBox-X";
        case VMNexusEngineTypePCem:       return @"PCem";
        case VMNexusEngineType86Box:      return @"86Box";
        case VMNexusEngineTypeVICE:       return @"VICE";
        case VMNexusEngineTypeFSUAE:      return @"FS-UAE";
        case VMNexusEngineTypeHatari:     return @"Hatari";
        case VMNexusEngineTypeOpenMSX:    return @"openMSX";
        case VMNexusEngineTypeFuse:       return @"Fuse";
        case VMNexusEngineTypeScummVM:    return @"ScummVM";
        case VMNexusEngineTypeMednafen:   return @"Mednafen";
        case VMNexusEngineTypeARAnyM:     return @"ARAnyM";
        default:                        return @"Unknown";
    }
}

+ (nullable NSString *)executablePathForEngineType:(VMNexusEngineType)type {
    switch (type) {
        case VMNexusEngineTypeQEMU: {
            // Handled by VMNexusQEMUProcess version detection; return a generic marker
            return @"/usr/local/bin/qemu-system-x86_64";
        }
        case VMNexusEngineTypeBasiliskII: {
            NSArray *paths = @[
                @"/Applications/BasiliskII.app/Contents/MacOS/BasiliskII",
                @"/Applications/Basilisk II.app/Contents/MacOS/BasiliskII",
                @"/opt/homebrew/bin/BasiliskII",
                @"/usr/local/bin/BasiliskII",
            ];
            NSString *found = FirstExistingExecutable(paths);
            return found ?: FindInApplications(@"Basilisk", @"BasiliskII");
        }
        case VMNexusEngineTypeMiniVMac: {
            NSArray *paths = @[
                @"/Applications/Mini vMac.app/Contents/MacOS/minivmac",
                @"/Applications/Mini vMac.app/Contents/MacOS/Mini vMac",
                @"/opt/homebrew/bin/minivmac",
                @"/usr/local/bin/minivmac",
            ];
            NSString *found = FirstExistingExecutable(paths);
            return found ?: FindInApplications(@"Mini vMac", nil);
        }
        case VMNexusEngineTypeSheepShaver: {
            return FindExecutableWithAppFallback(@"SheepShaver", @"SheepShaver");
        }
        case VMNexusEngineTypeDOSBox: {
            return FindExecutableWithAppFallback(@"dosbox", @"DOSBox");
        }
        case VMNexusEngineTypeDOSBoxX: {
            return FindExecutableWithAppFallback(@"dosbox-x", @"DOSBox-X");
        }
        case VMNexusEngineTypePCem: {
            return FindExecutableWithAppFallback(@"pcem", @"PCem");
        }
        case VMNexusEngineType86Box: {
            return FindExecutableWithAppFallback(@"86Box", @"86Box");
        }
        case VMNexusEngineTypeVICE: {
            NSArray *paths = @[
                @"/Applications/VICE.app/Contents/MacOS/x64sc",
                @"/opt/homebrew/bin/x64sc",
                @"/usr/local/bin/x64sc",
            ];
            NSString *found = FirstExistingExecutable(paths);
            return found ?: FindInApplications(@"VICE", @"x64sc");
        }
        case VMNexusEngineTypeFSUAE: {
            return FindExecutableWithAppFallback(@"fs-uae", @"FS-UAE");
        }
        case VMNexusEngineTypeHatari: {
            return FindExecutableWithAppFallback(@"hatari", @"Hatari");
        }
        case VMNexusEngineTypeOpenMSX: {
            return FindExecutableWithAppFallback(@"openmsx", @"OpenMSX");
        }
        case VMNexusEngineTypeFuse: {
            return FindExecutableWithAppFallback(@"fuse", @"Fuse");
        }
        case VMNexusEngineTypeScummVM: {
            return FindExecutableWithAppFallback(@"scummvm", @"ScummVM");
        }
        case VMNexusEngineTypeMednafen: {
            return FindExecutableWithAppFallback(@"mednafen", @"Mednafen");
        }
        case VMNexusEngineTypeARAnyM: {
            return FindExecutableWithAppFallback(@"aranym", @"ARAnyM");
        }
        default: return nil;
    }
}

+ (nullable NSString *)executablePathForMachineType:(NSString *)machineType {
    return [self executablePathForEngineType:[self engineTypeForMachine:machineType]];
}

@end
