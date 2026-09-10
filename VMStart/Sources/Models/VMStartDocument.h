//
//  VMStartDocument.h
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Cocoa/Cocoa.h>
#import "VMStartVirtualMachine.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMStartDocument : NSDocument

@property (nonatomic, strong) VMStartVirtualMachine *virtualMachine;

@end

NS_ASSUME_NONNULL_END
