//
//  VMStartConfigWindowController.h
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Cocoa/Cocoa.h>
#import "VMStartVirtualMachine.h"

NS_ASSUME_NONNULL_BEGIN

@protocol VMStartConfigDelegate <NSObject>
- (void)configDidSaveVM:(VMStartVirtualMachine *)vm;
@end

@interface VMStartConfigWindowController : NSWindowController

@property (nonatomic, strong) VMStartVirtualMachine *virtualMachine;
@property (nonatomic, weak, nullable) id<VMStartConfigDelegate> delegate;
@property (nonatomic, assign) BOOL isNewVM;

- (instancetype)initWithVM:(VMStartVirtualMachine *)vm isNew:(BOOL)isNew;

@end

NS_ASSUME_NONNULL_END
