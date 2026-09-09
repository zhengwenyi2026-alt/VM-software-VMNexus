//
//  VMNexusConfigWindowController.h
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Cocoa/Cocoa.h>
#import "VMNexusVirtualMachine.h"

NS_ASSUME_NONNULL_BEGIN

@protocol VMNexusConfigDelegate <NSObject>
- (void)configDidSaveVM:(VMNexusVirtualMachine *)vm;
@end

@interface VMNexusConfigWindowController : NSWindowController

@property (nonatomic, strong) VMNexusVirtualMachine *virtualMachine;
@property (nonatomic, weak, nullable) id<VMNexusConfigDelegate> delegate;
@property (nonatomic, assign) BOOL isNewVM;

- (instancetype)initWithVM:(VMNexusVirtualMachine *)vm isNew:(BOOL)isNew;

@end

NS_ASSUME_NONNULL_END
