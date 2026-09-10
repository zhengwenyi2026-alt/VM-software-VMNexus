//
//  VMStartAppDelegate.m
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMStartAppDelegate.h"
#import "VMStartLibraryWindowController.h"
#import "VMStartArchitectureManager.h"
#import "VMStartLocalization.h"
#import "VMStartDiskManagerController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <sys/resource.h>

@interface VMStartAppDelegate ()
@property (nonatomic, strong) VMStartLibraryWindowController *libraryWC;
@end

@implementation VMStartAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    if (![[VMStartArchitectureManager sharedManager] isQEMUInstalled]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = AMLocalizedString(@"alert.qemuNotFound.title");
        alert.informativeText = AMLocalizedString(@"alert.qemuNotFound.message");
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:AMLocalizedString(@"alert.ok")];
        [alert runModal];
    }
    [self setupMainMenu];
    self.libraryWC = [[VMStartLibraryWindowController alloc] init];
    [self.libraryWC showWindow:nil];
    // Auto-start VMs marked for auto-start
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self autoStartVMs];
    });
    // Lower priority when app goes to background
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidResignActive:) name:NSApplicationDidResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:NSApplicationDidBecomeActiveNotification object:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appDidResignActive:(NSNotification *)note {
    setpriority(PRIO_PROCESS, 0, 10); // nice +10 when background
}

- (void)appDidBecomeActive:(NSNotification *)note {
    setpriority(PRIO_PROCESS, 0, 0); // restore normal priority
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)setupMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];
    // App menu
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:AMLocalizedString(@"menu.about") action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *prefsItem = [[NSMenuItem alloc] init];
    prefsItem.title = AMLocalizedString(@"menu.settings");
    prefsItem.keyEquivalent = @",";
    prefsItem.action = @selector(showPreferences:);
    [appMenu addItem:prefsItem];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *hideItem = [[NSMenuItem alloc] init];
    hideItem.title = AMLocalizedString(@"menu.hide");
    hideItem.keyEquivalent = @"h";
    hideItem.action = @selector(hide:);
    [appMenu addItem:hideItem];
    NSMenuItem *hideOthersItem = [[NSMenuItem alloc] init];
    hideOthersItem.title = AMLocalizedString(@"menu.hideOthers");
    hideOthersItem.keyEquivalent = @"h";
    hideOthersItem.keyEquivalentModifierMask = NSEventModifierFlagOption | NSEventModifierFlagCommand;
    hideOthersItem.action = @selector(hideOtherApplications:);
    [appMenu addItem:hideOthersItem];
    [appMenu addItemWithTitle:AMLocalizedString(@"menu.showAll") action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *quitItem = [[NSMenuItem alloc] init];
    quitItem.title = AMLocalizedString(@"menu.quit");
    quitItem.keyEquivalent = @"q";
    quitItem.action = @selector(terminate:);
    [appMenu addItem:quitItem];
    appMenuItem.submenu = appMenu;
    [mainMenu addItem:appMenuItem];
    // File menu
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:AMLocalizedString(@"menu.file")];
    NSMenuItem *newVMItem = [[NSMenuItem alloc] init];
    newVMItem.title = AMLocalizedString(@"menu.newVM");
    newVMItem.keyEquivalent = @"n";
    newVMItem.action = @selector(newVM:);
    [fileMenu addItem:newVMItem];
    NSMenuItem *openVMItem = [[NSMenuItem alloc] init];
    openVMItem.title = AMLocalizedString(@"menu.openVM");
    openVMItem.keyEquivalent = @"o";
    openVMItem.action = @selector(openVM:);
    [fileMenu addItem:openVMItem];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:AMLocalizedString(@"menu.close") action:@selector(performClose:) keyEquivalent:@"w"];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *diskMgrItem = [[NSMenuItem alloc] init];
    diskMgrItem.title = @"Disk Manager...";
    diskMgrItem.action = @selector(openDiskManager:);
    [fileMenu addItem:diskMgrItem];
    fileMenuItem.submenu = fileMenu;
    [mainMenu addItem:fileMenuItem];
    // Edit menu
    NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:AMLocalizedString(@"menu.edit")];
    [editMenu addItemWithTitle:AMLocalizedString(@"menu.undo") action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:AMLocalizedString(@"menu.redo") action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:AMLocalizedString(@"menu.cut") action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:AMLocalizedString(@"menu.copy") action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:AMLocalizedString(@"menu.paste") action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:AMLocalizedString(@"menu.selectAll") action:@selector(selectAll:) keyEquivalent:@"a"];
    editMenuItem.submenu = editMenu;
    [mainMenu addItem:editMenuItem];
    // VM menu
    NSMenuItem *vmMenuItem = [[NSMenuItem alloc] init];
    NSMenu *vmMenu = [[NSMenu alloc] initWithTitle:AMLocalizedString(@"menu.vm")];
    NSMenuItem *startItem = [[NSMenuItem alloc] init];
    startItem.title = AMLocalizedString(@"menu.start");
    startItem.keyEquivalent = @"s";
    startItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    startItem.action = @selector(startSelectedVM:);
    [vmMenu addItem:startItem];
    [vmMenu addItem:[NSMenuItem separatorItem]];
    [vmMenu addItemWithTitle:AMLocalizedString(@"menu.pause") action:@selector(pauseVM:) keyEquivalent:@""];
    [vmMenu addItemWithTitle:AMLocalizedString(@"menu.resume") action:@selector(resumeVM:) keyEquivalent:@""];
    [vmMenu addItemWithTitle:AMLocalizedString(@"menu.stop") action:@selector(stopVM:) keyEquivalent:@""];
    [vmMenu addItem:[NSMenuItem separatorItem]];
    [vmMenu addItemWithTitle:AMLocalizedString(@"menu.vmSettings") action:@selector(editSelectedVM:) keyEquivalent:@""];
    [vmMenu addItem:[NSMenuItem separatorItem]];
    [vmMenu addItemWithTitle:AMLocalizedString(@"menu.refreshLibrary") action:@selector(refreshLibrary:) keyEquivalent:@"r"];
    vmMenuItem.submenu = vmMenu;
    [mainMenu addItem:vmMenuItem];
    // Window menu
    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:AMLocalizedString(@"menu.window")];
    [windowMenu addItemWithTitle:AMLocalizedString(@"menu.minimize") action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:AMLocalizedString(@"menu.zoom") action:@selector(performZoom:) keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:AMLocalizedString(@"menu.bringToFront") action:@selector(arrangeInFront:) keyEquivalent:@""];
    windowMenuItem.submenu = windowMenu;
    [mainMenu addItem:windowMenuItem];
    // Help menu
    NSMenuItem *helpMenuItem = [[NSMenuItem alloc] init];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:AMLocalizedString(@"menu.help")];
    [helpMenu addItemWithTitle:AMLocalizedString(@"menu.documentation") action:@selector(showHelp:) keyEquivalent:@"?"];
    helpMenuItem.submenu = helpMenu;
    [mainMenu addItem:helpMenuItem];
    
    [NSApp setMainMenu:mainMenu];
}

#pragma mark - Menu Actions

- (void)newVM:(id)sender {
    [self.libraryWC addVM:sender];
}

- (void)openVM:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = YES;
    panel.canChooseFiles = YES;
    panel.allowedContentTypes = @[UTTypeFolder];
    panel.allowsMultipleSelection = NO;
    panel.message = AMLocalizedString(@"openPanel.message");
    [panel beginSheetModalForWindow:self.libraryWC.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            [self.libraryWC refreshVMList];
        }
    }];
}

- (void)startSelectedVM:(id)sender {
    [self.libraryWC startVM:sender];
}

- (void)editSelectedVM:(id)sender {
    [self.libraryWC editVM:sender];
}

- (void)refreshLibrary:(id)sender {
    [self.libraryWC refreshVMList];
}

- (void)pauseVM:(id)sender { }
- (void)resumeVM:(id)sender { }
- (void)stopVM:(id)sender { }
- (void)showPreferences:(id)sender { }
- (void)showHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/zhengwenyi2026-alt/VMStart"]];
}

- (void)autoStartVMs {
    for (VMStartVirtualMachine *vm in self.libraryWC.virtualMachines) {
        if (vm.autoStart && vm.status != VMStartStatusRunning) {
            [self.libraryWC startVM:nil];
        }
    }
}

- (void)openDiskManager:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowedContentTypes = @[@"public.data"];
    panel.title = @"Select Disk Image";
    [panel beginSheetModalForWindow:self.libraryWC.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            VMStartDiskManagerController *diskMgr = [[VMStartDiskManagerController alloc] initWithDiskPath:panel.URL.path];
            [diskMgr showWindow:nil];
        }
    }];
}

@end
