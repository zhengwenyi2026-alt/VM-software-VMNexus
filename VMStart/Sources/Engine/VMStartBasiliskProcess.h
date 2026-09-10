//
//  VMStartBasiliskProcess.h
//  VMStart
//
//  BasiliskII engine wrapper — Mac 68k II / LC / Centris / Quadra series
//  Supports: Mac OS 7.x – 8.1, 68020/030/040
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Foundation/Foundation.h>
#import "VMStartEngineProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMStartBasiliskProcess : NSObject <VMStartEngine>

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
