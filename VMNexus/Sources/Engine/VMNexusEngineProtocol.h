//
//  VMNexusEngineProtocol.h
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Foundation/Foundation.h>
#import "VMNexusVirtualMachine.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VMNexusEngineType) {
    VMNexusEngineTypeQEMU       = 0,  // All modern/general architectures
    VMNexusEngineTypeBasiliskII = 1,  // 68020/030/040 Mac II family
    VMNexusEngineTypeMiniVMac   = 2,  // 68000 very early Mac
    VMNexusEngineTypeSheepShaver = 3, // PowerPC Mac
    VMNexusEngineTypeDOSBox     = 4,  // MS-DOS
    VMNexusEngineTypeDOSBoxX    = 5,  // MS-DOS / Windows 9x
    VMNexusEngineTypePCem       = 6,  // IBM PC
    VMNexusEngineType86Box      = 7,  // IBM PC
    VMNexusEngineTypeVICE       = 8,  // Commodore 8-bit
    VMNexusEngineTypeFSUAE      = 9,  // Amiga
    VMNexusEngineTypeHatari     = 10, // Atari ST/STE/TT/Falcon
    VMNexusEngineTypeOpenMSX    = 11, // MSX
    VMNexusEngineTypeFuse       = 12, // ZX Spectrum
    VMNexusEngineTypeScummVM    = 13, // Adventure game engine
    VMNexusEngineTypeMednafen   = 14, // Multi-system console
    VMNexusEngineTypeARAnyM     = 15, // Atari ST/TT/Falcon VM
    VMNexusEngineTypeCount      = 16  // Keep last
};

/// Unified delegate for all engine types (same interface as QEMU delegate)
@protocol VMNexusEngineDelegate <NSObject>
@optional
- (void)engineDidStart:(id)sender;
- (void)engineDidStop:(id)sender exitCode:(NSInteger)code;
- (void)engine:(id)sender didOutputData:(NSData *)data;
- (void)engine:(id)sender didOutputError:(NSData *)data;
- (void)engine:(id)sender didFailWithError:(NSError *)error;
@end

/// Abstract engine protocol - all engine wrappers conform to this
@protocol VMNexusEngine <NSObject>
@required
@property (nonatomic, strong, readonly) VMNexusVirtualMachine *virtualMachine;
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, weak, nullable) id<VMNexusEngineDelegate> delegate;
@property (nonatomic, assign, readonly) VMNexusEngineType engineType;

- (instancetype)initWithVirtualMachine:(VMNexusVirtualMachine *)vm;
- (BOOL)startWithError:(NSError **)error;
- (void)stop;
- (void)forceStop;
@optional
- (void)pause;
- (void)resume;
@property (nonatomic, assign, readonly) NSInteger processIdentifier;
- (void)sendMonitorCommand:(NSString *)command completion:(nullable void(^)(NSString * _Nullable result))completion;
- (BOOL)captureScreenshotToPath:(NSString *)path;
@end

NS_ASSUME_NONNULL_END
