//
//  VMNexusConsoleWindowController.h
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Cocoa/Cocoa.h>
#import "VMNexusVirtualMachine.h"
#import "VMNexusQEMUProcess.h"
#import "VMNexusEngineProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMNexusConsoleWindowController : NSWindowController <VMNexusQEMUProcessDelegate, VMNexusEngineDelegate>

@property (nonatomic, strong) VMNexusVirtualMachine *virtualMachine;
// Legacy QEMU process (kept for monitor commands / media hot-swap)
@property (nonatomic, strong, nullable) VMNexusQEMUProcess *qemuProcess;
// Generic engine (could be QEMU, BasiliskII or MiniVMac)
@property (nonatomic, strong) id<VMNexusEngine> engine;

- (instancetype)initWithVM:(VMNexusVirtualMachine *)vm;
- (void)startVM;
- (void)stopVM;

@end

NS_ASSUME_NONNULL_END

