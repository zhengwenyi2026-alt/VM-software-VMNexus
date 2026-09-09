//
//  VMNexusLibraryWindowController.h
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Cocoa/Cocoa.h>
#import "VMNexusVirtualMachine.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMNexusLibraryWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) NSMutableArray<VMNexusVirtualMachine *> *virtualMachines;
@property (nonatomic, strong, nullable) NSString *vmDirectory;

- (void)refreshVMList;
- (void)addVM:(nullable id)sender;
- (void)removeVM:(nullable id)sender;
- (void)editVM:(nullable id)sender;
- (void)startVM:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
