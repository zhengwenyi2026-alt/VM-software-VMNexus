//
//  VMNexusEngineSelector.h
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Foundation/Foundation.h>
#import "VMNexusEngineProtocol.h"
#import "VMNexusVirtualMachine.h"

NS_ASSUME_NONNULL_BEGIN

/// Transparently selects the best engine for a given VM and returns an engine instance.
/// Users never see engine names — the selection is fully automatic.
@interface VMNexusEngineSelector : NSObject

/// Returns the appropriate engine instance for this VM.
+ (id<VMNexusEngine>)engineForVM:(VMNexusVirtualMachine *)vm;

/// Returns the engine type that would be chosen for a VM.
+ (VMNexusEngineType)engineTypeForVM:(VMNexusVirtualMachine *)vm;

/// Returns the engine type for a given machine type string.
+ (VMNexusEngineType)engineTypeForMachine:(NSString *)machineType;

/// Human-readable name for an engine type (for logs only).
+ (NSString *)nameForEngineType:(VMNexusEngineType)type;

/// Finds the installed executable for an engine type, or nil if not installed.
+ (nullable NSString *)executablePathForEngineType:(VMNexusEngineType)type;

/// Finds the installed executable for a specific machine type.
+ (nullable NSString *)executablePathForMachineType:(NSString *)machineType;

@end

NS_ASSUME_NONNULL_END
