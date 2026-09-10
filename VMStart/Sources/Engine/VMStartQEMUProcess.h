//
//  VMStartQEMUProcess.h
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Foundation/Foundation.h>
#import "VMStartVirtualMachine.h"

NS_ASSUME_NONNULL_BEGIN

@protocol VMStartQEMUProcessDelegate <NSObject>
@optional
- (void)qemuProcessDidStart:(id)sender;
- (void)qemuProcessDidStop:(id)sender exitCode:(NSInteger)code;
- (void)qemuProcess:(id)sender didOutputData:(NSData *)data;
- (void)qemuProcess:(id)sender didOutputError:(NSData *)data;
- (void)qemuProcess:(id)sender didFailWithError:(NSError *)error;
@end

@interface VMStartQEMUProcess : NSObject

@property (nonatomic, strong, readonly) VMStartVirtualMachine *virtualMachine;
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, assign, readonly) NSInteger processIdentifier;
@property (nonatomic, weak, nullable) id<VMStartQEMUProcessDelegate> delegate;
@property (nonatomic, strong, readonly) NSString *logOutput;

- (instancetype)initWithVirtualMachine:(VMStartVirtualMachine *)vm;
- (BOOL)startWithError:(NSError **)error;
- (void)stop;
- (void)forceStop;
- (void)pause;
- (void)resume;
- (void)sendMonitorCommand:(NSString *)command completion:(nullable void(^)(NSString * _Nullable result))completion;
- (BOOL)captureScreenshotToPath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
