//
//  VMStartConsoleWindowController.h
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Cocoa/Cocoa.h>
#import "VMStartVirtualMachine.h"
#import "VMStartQEMUProcess.h"
#import "VMStartEngineProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMStartConsoleWindowController : NSWindowController <VMStartQEMUProcessDelegate, VMStartEngineDelegate>

@property (nonatomic, strong) VMStartVirtualMachine *virtualMachine;
// Legacy QEMU process (kept for monitor commands / media hot-swap)
@property (nonatomic, strong, nullable) VMStartQEMUProcess *qemuProcess;
// Generic engine (could be QEMU, BasiliskII or MiniVMac)
@property (nonatomic, strong) id<VMStartEngine> engine;

- (instancetype)initWithVM:(VMStartVirtualMachine *)vm;
- (void)startVM;
- (void)stopVM;

@end

NS_ASSUME_NONNULL_END

