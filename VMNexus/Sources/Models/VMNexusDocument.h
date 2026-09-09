//
//  VMNexusDocument.h
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Cocoa/Cocoa.h>
#import "VMNexusVirtualMachine.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMNexusDocument : NSDocument

@property (nonatomic, strong) VMNexusVirtualMachine *virtualMachine;

@end

NS_ASSUME_NONNULL_END
