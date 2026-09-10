//
//  VMStartEngineSelector.h
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Foundation/Foundation.h>
#import "VMStartEngineProtocol.h"
#import "VMStartVirtualMachine.h"

NS_ASSUME_NONNULL_BEGIN

/// Transparently selects the best engine for a given VM and returns an engine instance.
/// Users never see engine names — the selection is fully automatic.
@interface VMStartEngineSelector : NSObject

/// Returns the appropriate engine instance for this VM.
+ (id<VMStartEngine>)engineForVM:(VMStartVirtualMachine *)vm;

/// Returns the engine type that would be chosen for a VM.
+ (VMStartEngineType)engineTypeForVM:(VMStartVirtualMachine *)vm;

/// Returns the engine type for a given machine type string.
+ (VMStartEngineType)engineTypeForMachine:(NSString *)machineType;

/// Human-readable name for an engine type (for logs only).
+ (NSString *)nameForEngineType:(VMStartEngineType)type;

/// Finds the installed executable for an engine type, or nil if not installed.
+ (nullable NSString *)executablePathForEngineType:(VMStartEngineType)type;

/// Finds the installed executable for a specific machine type.
+ (nullable NSString *)executablePathForMachineType:(NSString *)machineType;

@end

NS_ASSUME_NONNULL_END
