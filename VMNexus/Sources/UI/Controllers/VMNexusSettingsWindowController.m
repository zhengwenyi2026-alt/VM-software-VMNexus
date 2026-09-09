//
//  VMNexusSettingsWindowController.m
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusSettingsWindowController.h"

@interface VMNexusSettingsWindowController ()

@property (nonatomic, strong) NSView *contentView;
@property (nonatomic, strong) NSTabView *tabView;

@end

@implementation VMNexusSettingsWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 400)
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = NSLocalizedString(@"settings.title", @"Settings");
    [window center];
    
    self = [super initWithWindow:window];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.contentView = [[NSView alloc] initWithFrame:self.window.contentView.bounds];
    self.contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.window.contentView = self.contentView;
    
    // Tab view for settings categories
    self.tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(20, 20, self.contentView.bounds.size.width - 40, self.contentView.bounds.size.height - 40)];
    self.tabView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    // General tab
    NSTabViewItem *generalTab = [[NSTabViewItem alloc] initWithIdentifier:@"general"];
    generalTab.label = NSLocalizedString(@"settings.general", @"General");
    generalTab.view = [self createGeneralView];
    
    // Advanced tab
    NSTabViewItem *advancedTab = [[NSTabViewItem alloc] initWithIdentifier:@"advanced"];
    advancedTab.label = NSLocalizedString(@"settings.advanced", @"Advanced");
    advancedTab.view = [self createAdvancedView];
    
    self.tabView.tabViewItems = @[generalTab, advancedTab];
    [self.contentView addSubview:self.tabView];
}

- (NSView *)createGeneralView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
    
    CGFloat y = 260;
    
    // QEMU path setting
    NSTextField *qemuLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 100, 24)];
    qemuLabel.stringValue = NSLocalizedString(@"settings.qemuPath", @"QEMU Path:");
    qemuLabel.bezeled = NO;
    qemuLabel.drawsBackground = NO;
    qemuLabel.editable = NO;
    [view addSubview:qemuLabel];
    
    NSTextField *qemuPath = [[NSTextField alloc] initWithFrame:NSMakeRect(130, y, 250, 24)];
    qemuPath.stringValue = @"/opt/homebrew/bin";
    qemuPath.bezeled = YES;
    qemuPath.drawsBackground = YES;
    [view addSubview:qemuPath];
    
    y -= 40;
    
    // VM directory setting
    NSTextField *vmDirLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 100, 24)];
    vmDirLabel.stringValue = NSLocalizedString(@"settings.vmDirectory", @"VM Directory:");
    vmDirLabel.bezeled = NO;
    vmDirLabel.drawsBackground = NO;
    vmDirLabel.editable = NO;
    [view addSubview:vmDirLabel];
    
    NSTextField *vmDirPath = [[NSTextField alloc] initWithFrame:NSMakeRect(130, y, 250, 24)];
    vmDirPath.stringValue = @"~/Library/Application Support/VMNexus/VirtualMachines";
    vmDirPath.bezeled = YES;
    vmDirPath.drawsBackground = YES;
    [view addSubview:vmDirPath];
    
    y -= 40;
    
    // Auto-start checkbox
    NSButton *autoStart = [[NSButton alloc] initWithFrame:NSMakeRect(20, y, 200, 24)];
    autoStart.title = NSLocalizedString(@"settings.autoStart", @"Auto-start VMs on login");
    autoStart.bezelStyle = NSBezelStyleInline;
    autoStart.state = NSControlStateValueOff;
    [view addSubview:autoStart];
    
    return view;
}

- (NSView *)createAdvancedView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
    
    CGFloat y = 260;
    
    // Enable debug mode
    NSButton *debugMode = [[NSButton alloc] initWithFrame:NSMakeRect(20, y, 200, 24)];
    debugMode.title = NSLocalizedString(@"settings.debugMode", @"Enable debug mode");
    debugMode.bezelStyle = NSBezelStyleInline;
    debugMode.state = NSControlStateValueOff;
    [view addSubview:debugMode];
    
    y -= 40;
    
    // Enable experimental features
    NSButton *experimental = [[NSButton alloc] initWithFrame:NSMakeRect(20, y, 200, 24)];
    experimental.title = NSLocalizedString(@"settings.experimental", @"Enable experimental features");
    experimental.bezelStyle = NSBezelStyleInline;
    experimental.state = NSControlStateValueOff;
    [view addSubview:experimental];
    
    return view;
}

@end
