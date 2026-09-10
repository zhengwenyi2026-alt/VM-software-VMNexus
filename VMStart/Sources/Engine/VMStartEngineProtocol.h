//
//  VMStartEngineProtocol.h
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Foundation/Foundation.h>
#import "VMStartVirtualMachine.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VMStartEngineType) {
    VMStartEngineTypeQEMU       = 0,  // All modern/general architectures
    VMStartEngineTypeBasiliskII = 1,  // 68020/030/040 Mac II family
    VMStartEngineTypeMiniVMac   = 2,  // 68000 very early Mac
    VMStartEngineTypeSheepShaver = 3, // PowerPC Mac
    VMStartEngineTypeDOSBox     = 4,  // MS-DOS
    VMStartEngineTypeDOSBoxX    = 5,  // MS-DOS / Windows 9x
    VMStartEngineTypePCem       = 6,  // IBM PC
    VMStartEngineType86Box      = 7,  // IBM PC
    VMStartEngineTypeVICE       = 8,  // Commodore 8-bit
    VMStartEngineTypeFSUAE      = 9,  // Amiga
    VMStartEngineTypeHatari     = 10, // Atari ST/STE/TT/Falcon
    VMStartEngineTypeOpenMSX    = 11, // MSX
    VMStartEngineTypeFuse       = 12, // ZX Spectrum
    VMStartEngineTypeScummVM    = 13, // Adventure game engine
    VMStartEngineTypeMednafen   = 14, // Multi-system console
    VMStartEngineTypeARAnyM     = 15, // Atari ST/TT/Falcon VM
    VMStartEngineTypeCount      = 16  // Keep last
};

/// Unified delegate for all engine types (same interface as QEMU delegate)
@protocol VMStartEngineDelegate <NSObject>
@optional
- (void)engineDidStart:(id)sender;
- (void)engineDidStop:(id)sender exitCode:(NSInteger)code;
- (void)engine:(id)sender didOutputData:(NSData *)data;
- (void)engine:(id)sender didOutputError:(NSData *)data;
- (void)engine:(id)sender didFailWithError:(NSError *)error;
@end

/// Abstract engine protocol - all engine wrappers conform to this
@protocol VMStartEngine <NSObject>
@required
@property (nonatomic, strong, readonly) VMStartVirtualMachine *virtualMachine;
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, weak, nullable) id<VMStartEngineDelegate> delegate;
@property (nonatomic, assign, readonly) VMStartEngineType engineType;

- (instancetype)initWithVirtualMachine:(VMStartVirtualMachine *)vm;
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
