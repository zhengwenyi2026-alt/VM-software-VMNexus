//
//  VMNexusArchitectureManager.h
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Foundation/Foundation.h>
#import "VMNexusVirtualMachine.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMNexusMachineInfo : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *machineDescription;
@property (nonatomic, assign) BOOL isDeprecated;
@property (nonatomic, assign) BOOL isDefault;
@end

@interface VMNexusArchitectureProfile : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, assign) VMNexusArchitecture architecture;
@property (nonatomic, copy) NSString *qemuBinary;
@property (nonatomic, copy) NSArray<NSString *> *supportedMachines;
@property (nonatomic, copy) NSString *defaultMachine;
@property (nonatomic, copy) NSArray<NSString *> *supportedCPUs;
@property (nonatomic, copy) NSString *defaultCPU;
@property (nonatomic, assign) NSInteger minMemoryMB;
@property (nonatomic, assign) NSInteger maxMemoryMB;
@property (nonatomic, assign) NSInteger defaultMemoryMB;
@property (nonatomic, assign) NSInteger bitWidth;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, assign) BOOL supportsAcceleration;
// Dynamic (runtime-queried) lists from installed QEMU
@property (nonatomic, copy, nullable) NSArray<VMNexusMachineInfo *> *dynamicMachines;
@property (nonatomic, copy, nullable) NSArray<NSString *> *dynamicCPUs;
- (NSArray<NSString *> *)allMachines;
- (NSArray<NSString *> *)allCPUs;
@end

@interface VMNexusArchitectureManager : NSObject

+ (instancetype)sharedManager;
- (NSArray<VMNexusArchitectureProfile *> *)allProfiles;
- (NSArray<VMNexusArchitectureProfile *> *)profilesForCategory:(NSString *)category;
- (NSArray<NSString *> *)allCategories;
- (nullable VMNexusArchitectureProfile *)profileForArchitecture:(VMNexusArchitecture)arch;
- (BOOL)isQEMUInstalled;
- (nullable NSString *)pathForQEMUBinary:(NSString *)binaryName;
- (NSArray<NSString *> *)availableQEMUBinaries;
- (NSString *)qemuVersionString;

// Dynamic QEMU querying
- (void)refreshDynamicData;
- (NSArray<VMNexusMachineInfo *> *)queryMachinesForBinary:(NSString *)binaryName;
- (NSArray<NSString *> *)queryCPUsForBinary:(NSString *)binaryName;
- (NSString *)qemuMajorMinorVersion;

@end

NS_ASSUME_NONNULL_END
