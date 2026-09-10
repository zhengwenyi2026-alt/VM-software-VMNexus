//
//  VMStartMiniVMacProcess.h
//  VMStart
//
//  Mini vMac engine wrapper — Mac 128K/512K/Plus/SE/Classic (68000 era)
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Foundation/Foundation.h>
#import "VMStartEngineProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMStartMiniVMacProcess : NSObject <VMStartEngine>

@property (nonatomic, strong, readonly) VMStartVirtualMachine *virtualMachine;
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, weak, nullable) id<VMStartEngineDelegate> delegate;
@property (nonatomic, assign, readonly) VMStartEngineType engineType;

- (instancetype)initWithVirtualMachine:(VMStartVirtualMachine *)vm;
- (BOOL)startWithError:(NSError **)error;
- (void)stop;
- (void)forceStop;

@end

NS_ASSUME_NONNULL_END
