//
//  VMNexusMiniVMacProcess.h
//  VMNexus
//
//  Mini vMac engine wrapper — Mac 128K/512K/Plus/SE/Classic (68000 era)
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Foundation/Foundation.h>
#import "VMNexusEngineProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMNexusMiniVMacProcess : NSObject <VMNexusEngine>

@property (nonatomic, strong, readonly) VMNexusVirtualMachine *virtualMachine;
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, weak, nullable) id<VMNexusEngineDelegate> delegate;
@property (nonatomic, assign, readonly) VMNexusEngineType engineType;

- (instancetype)initWithVirtualMachine:(VMNexusVirtualMachine *)vm;
- (BOOL)startWithError:(NSError **)error;
- (void)stop;
- (void)forceStop;

@end

NS_ASSUME_NONNULL_END
