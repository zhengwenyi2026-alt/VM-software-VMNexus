//
//  VMStartConfigWindowController.m
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMStartConfigWindowController.h"
#import "VMStartArchitectureManager.h"
#import "VMStartEngineSelector.h"
#import "VMStartLocalization.h"
#import "VMStartCardView.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface VMStartConfigWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSArray<VMStartArchitectureProfile *> *profiles;
@property (nonatomic, assign) NSInteger currentStep;
@property (nonatomic, strong) NSMutableArray<NSString *> *stepTitles;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSView *> *stepViews;
@property (nonatomic, strong) NSView *stepContainer;
@property (nonatomic, strong) NSView *stepSidebar;
@property (nonatomic, strong) NSTextField *stepTitleLabel;
@property (nonatomic, strong) NSButton *backButton;
@property (nonatomic, strong) NSButton *nextButton;
@property (nonatomic, strong) NSButton *cancelButton;

// Step 0: Overview
@property (nonatomic, strong) NSTextField *nameField;
@property (nonatomic, strong) NSPopUpButton *archPopup;
@property (nonatomic, strong) NSPopUpButton *osPopup;
@property (nonatomic, strong) NSPopUpButton *machinePopup;

// Step 1: Hardware
@property (nonatomic, strong) NSPopUpButton *cpuPopup;
@property (nonatomic, strong) NSSlider *cpuSlider;
@property (nonatomic, strong) NSTextField *cpuLabel;
@property (nonatomic, strong) NSPopUpButton *cpuSocketsPopup;
@property (nonatomic, strong) NSPopUpButton *cpuCoresPerSocketPopup;
@property (nonatomic, strong) NSTextField *memoryField;
@property (nonatomic, strong) NSPopUpButton *memoryUnitPopup;
@property (nonatomic, strong) NSSlider *memorySlider;
@property (nonatomic, strong) NSPopUpButton *diskControllerPopup;
@property (nonatomic, strong) NSPopUpButton *usbVersionPopup;
@property (nonatomic, strong) NSButton *tpmCheck;
@property (nonatomic, strong) NSPopUpButton *soundCardPopup;

// Step 2: Storage
@property (nonatomic, strong) NSTextField *diskField;
@property (nonatomic, strong) NSPopUpButton *diskUnitPopup;
@property (nonatomic, strong) NSButton *useExistingDiskCheck;
@property (nonatomic, strong) NSTextField *existingDiskField;

// Step 3: Boot Media
@property (nonatomic, strong) NSTextField *bootISOField;
@property (nonatomic, strong) NSTextField *cdromField;
@property (nonatomic, strong) NSTextField *floppyAField;
@property (nonatomic, strong) NSTextField *floppyBField;
@property (nonatomic, strong) NSTextField *biosField;
@property (nonatomic, strong) NSTextField *romField;
@property (nonatomic, strong) NSView *romRow;

// Step 4: Network & Sharing
@property (nonatomic, strong) NSPopUpButton *networkPopup;
@property (nonatomic, strong) NSPopUpButton *displayPopup;
@property (nonatomic, strong) NSButton *accelCheck;
@property (nonatomic, strong) NSButton *audioCheck;
@property (nonatomic, strong) NSButton *usbCheck;
@property (nonatomic, strong) NSButton *unityCheck;
@property (nonatomic, strong) NSButton *modemCheck;
@property (nonatomic, strong) NSPopUpButton *modemSpeedPopup;
@property (nonatomic, strong) NSButton *terminalCheck;
@property (nonatomic, strong) NSTableView *sharedFolderTable;
@property (nonatomic, strong) NSScrollView *sharedFolderScroll;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *sharedFoldersList;
@property (nonatomic, strong) NSTextField *portForwardField;

// Step 5: Display & Advanced
@property (nonatomic, strong) NSButton *accel3DCheck;
@property (nonatomic, strong) NSSlider *vramSlider;
@property (nonatomic, strong) NSTextField *vramLabel;
@property (nonatomic, strong) NSPopUpButton *monitorPopup;
@property (nonatomic, strong) NSButton *hidpiCheck;
@property (nonatomic, strong) NSButton *parallelCheck;
@property (nonatomic, strong) NSButton *sharedClipboardCheck;
@property (nonatomic, strong) NSButton *dragDropCheck;
@property (nonatomic, strong) NSButton *timeSyncCheck;
@property (nonatomic, strong) NSButton *autoSnapshotCheck;
@property (nonatomic, strong) NSTextField *autoSnapshotIntervalField;
@property (nonatomic, strong) NSButton *encryptCheck;
@property (nonatomic, strong) NSPopUpButton *performancePopup;
@property (nonatomic, strong) NSTextField *portForwardTable;
@property (nonatomic, strong) NSTextField *bridgeInterfaceField;
@property (nonatomic, strong) NSButton *dhcpCheck;
@property (nonatomic, strong) NSTextField *dhcpStartField;
@property (nonatomic, strong) NSTextField *dhcpEndField;
@property (nonatomic, strong) NSTextField *subnetField;
@property (nonatomic, strong) NSButton *ipv6Check;

// Step 6: Summary
@property (nonatomic, strong) NSTextView *summaryView;
@property (nonatomic, strong) NSScrollView *summaryScroll;
@property (nonatomic, assign) VMStartAppMode appMode;
@property (nonatomic, strong) VMStartModeSwitcher *modeSwitcher;
@end

@implementation VMStartConfigWindowController

- (instancetype)initWithVM:(VMStartVirtualMachine *)vm isNew:(BOOL)isNew {
    NSRect frame = NSMakeRect(0, 0, 760, 520);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];
    window.title = isNew ? AMLocalizedString(@"config.title.new") : [NSString stringWithFormat:@"%@ - %@", vm.name, AMLocalizedString(@"config.title.edit")];
    [window center];
    self = [super initWithWindow:window];
    if (self) {
        _virtualMachine = vm;
        _isNewVM = isNew;
        _sharedFoldersList = [NSMutableArray array];
        VMStartArchitectureManager *mgr = [VMStartArchitectureManager sharedManager];
        NSArray *profiles = [mgr allProfiles];
        if (profiles.count > 0) {
            VMStartArchitectureProfile *firstProfile = profiles.firstObject;
            if (firstProfile.dynamicMachines == nil) {
                [mgr refreshDynamicData];
            }
        }
        _profiles = profiles ?: @[];
        _currentStep = 0;
        _appMode = VMStartAppModeStandard;
        _stepTitles = [NSMutableArray arrayWithArray:@[
            AMLocalizedString(@"config.step.overview"),
            AMLocalizedString(@"config.step.hardware"),
            AMLocalizedString(@"config.step.storage"),
            AMLocalizedString(@"config.step.media"),
            AMLocalizedString(@"config.step.network"),
            @"Display & Advanced",
            AMLocalizedString(@"config.step.summary")
        ]];
        [self setupUI];
        [self populateFields];
    }
    return self;
}

- (void)setupUI {
    NSView *content = self.window.contentView;

    // Step sidebar
    self.stepSidebar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 180, content.bounds.size.height)];
    self.stepSidebar.autoresizingMask = NSViewHeightSizable;
    self.stepSidebar.wantsLayer = YES;
    self.stepSidebar.layer.backgroundColor = [[NSColor windowBackgroundColor] colorWithAlphaComponent:0.95].CGColor;
    [content addSubview:self.stepSidebar];

    NSView *sidebarLine = [[NSView alloc] initWithFrame:NSMakeRect(180, 0, 1, content.bounds.size.height)];
    sidebarLine.wantsLayer = YES;
    sidebarLine.layer.backgroundColor = [NSColor separatorColor].CGColor;
    sidebarLine.autoresizingMask = NSViewMaxXMargin | NSViewHeightSizable;
    [content addSubview:sidebarLine];

    [self refreshStepSidebar];

    // Mode switcher at top of sidebar
    self.modeSwitcher = [[VMStartModeSwitcher alloc] initWithFrame:NSMakeRect(8, self.stepSidebar.bounds.size.height - 36, 164, 26)];
    self.modeSwitcher.currentMode = self.appMode;
    self.modeSwitcher.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
    __weak typeof(self) weakSelf = self;
    self.modeSwitcher.onModeChange = ^(VMStartAppMode mode) {
        weakSelf.appMode = mode;
        [weakSelf updateNetworkStepForMode];
        [weakSelf updateDisplayStepForMode];
    };
    [self.stepSidebar addSubview:self.modeSwitcher];

    // Header
    self.stepTitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(204, content.bounds.size.height - 52, 400, 28)];
    self.stepTitleLabel.font = [NSFont boldSystemFontOfSize:18];
    self.stepTitleLabel.bezeled = NO; self.stepTitleLabel.drawsBackground = NO; self.stepTitleLabel.editable = NO;
    self.stepTitleLabel.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
    [content addSubview:self.stepTitleLabel];

    // Step container
    self.stepContainer = [[NSView alloc] initWithFrame:NSMakeRect(200, 64, content.bounds.size.width - 224, content.bounds.size.height - 128)];
    self.stepContainer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [content addSubview:self.stepContainer];

    // Build all step views upfront so populateFields can set values
    self.stepViews = [NSMutableDictionary dictionary];
    for (NSInteger i = 0; i < self.stepTitles.count; i++) {
        NSView *view = [self buildStepView:i];
        view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.stepViews[@(i)] = view;
        [self.stepContainer addSubview:view];
        view.hidden = YES;
    }

    // Bottom buttons
    self.cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(content.bounds.size.width - 340, 16, 90, 32)];
    self.cancelButton.title = AMLocalizedString(@"config.cancel");
    self.cancelButton.bezelStyle = NSBezelStyleRounded;
    self.cancelButton.target = self; self.cancelButton.action = @selector(cancelConfig:);
    self.cancelButton.autoresizingMask = NSViewMinXMargin;
    [content addSubview:self.cancelButton];

    self.backButton = [[NSButton alloc] initWithFrame:NSMakeRect(content.bounds.size.width - 240, 16, 90, 32)];
    self.backButton.title = AMLocalizedString(@"config.back");
    self.backButton.bezelStyle = NSBezelStyleRounded;
    self.backButton.target = self; self.backButton.action = @selector(goBack:);
    self.backButton.autoresizingMask = NSViewMinXMargin;
    [content addSubview:self.backButton];

    self.nextButton = [[NSButton alloc] initWithFrame:NSMakeRect(content.bounds.size.width - 140, 16, 120, 32)];
    self.nextButton.title = AMLocalizedString(@"config.next");
    self.nextButton.bezelStyle = NSBezelStyleRounded;
    self.nextButton.keyEquivalent = @"\r";
    self.nextButton.target = self; self.nextButton.action = @selector(goNext:);
    self.nextButton.autoresizingMask = NSViewMinXMargin;
    [content addSubview:self.nextButton];

    [self showStep:0];
}

- (void)refreshStepSidebar {
    for (NSView *sub in [self.stepSidebar.subviews copy]) [sub removeFromSuperview];
    CGFloat y = self.stepSidebar.bounds.size.height - 40;
    for (NSInteger i = 0; i < self.stepTitles.count; i++) {
        NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(16, y - i * 32, 148, 22)];
        label.stringValue = [NSString stringWithFormat:@"%ld. %@", (long)(i + 1), self.stepTitles[i]];
        label.font = [NSFont systemFontOfSize:12 weight:(i == self.currentStep ? NSFontWeightSemibold : NSFontWeightRegular)];
        label.textColor = (i == self.currentStep) ? [NSColor controlAccentColor] : [NSColor secondaryLabelColor];
        label.bezeled = NO; label.drawsBackground = NO; label.editable = NO;
        [self.stepSidebar addSubview:label];
    }
}

- (void)showStep:(NSInteger)step {
    self.currentStep = step;
    self.stepTitleLabel.stringValue = self.stepTitles[step];
    [self refreshStepSidebar];

    NSNumber *key = @(step);
    if (!self.stepViews[key]) {
        NSView *view = [self buildStepView:step];
        view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.stepViews[key] = view;
        [self.stepContainer addSubview:view];
    }
    for (NSView *sub in self.stepContainer.subviews) {
        sub.hidden = (sub != self.stepViews[key]);
    }

    [self updateButtons];
    [self updateUIForCurrentMachine];
    if (step == self.stepTitles.count - 1) [self refreshSummary];
}

- (NSView *)buildStepView:(NSInteger)step {
    switch (step) {
        case 0: return [self buildOverviewStep];
        case 1: return [self buildHardwareStep];
        case 2: return [self buildStorageStep];
        case 3: return [self buildMediaStep];
        case 4: return [self buildNetworkStep];
        case 5: return [self buildDisplayAdvancedStep];
        case 6: return [self buildSummaryStep];
    }
    return [[NSView alloc] initWithFrame:self.stepContainer.bounds];
}

- (void)updateButtons {
    self.backButton.enabled = self.currentStep > 0;
    if (self.currentStep == self.stepTitles.count - 1) {
        self.nextButton.title = self.isNewVM ? AMLocalizedString(@"config.create") : AMLocalizedString(@"config.save");
    } else {
        self.nextButton.title = AMLocalizedString(@"config.next");
    }
}

- (void)goBack:(id)sender {
    if (self.currentStep > 0) [self showStep:self.currentStep - 1];
}

- (void)goNext:(id)sender {
    if (self.currentStep < self.stepTitles.count - 1) {
        [self showStep:self.currentStep + 1];
    } else {
        [self saveConfig:sender];
    }
}

#pragma mark - Step Builders

- (NSView *)buildOverviewStep {
    NSView *view = [[NSView alloc] initWithFrame:self.stepContainer.bounds];
    CGFloat y = view.bounds.size.height - 40;

    [self addLabel:AMLocalizedString(@"config.vmName") at:NSMakePoint(0, y) toView:view width:120];
    self.nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, y - 2, 360, 24)];
    self.nameField.bezelStyle = NSTextFieldSquareBezel;
    [view addSubview:self.nameField];
    y -= 56;

    [self addLabel:AMLocalizedString(@"config.architecture") at:NSMakePoint(0, y) toView:view width:120];
    self.archPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 360, 26)];
    for (VMStartArchitectureProfile *p in self.profiles) {
        [self.archPopup addItemWithTitle:[NSString stringWithFormat:@"%@ (%ld-bit)", p.displayName, (long)p.bitWidth]];
        self.archPopup.lastItem.representedObject = p;
    }
    [self.archPopup setTarget:self];
    [self.archPopup setAction:@selector(archChanged:)];
    [view addSubview:self.archPopup];
    y -= 56;

    [self addLabel:@"Guest OS" at:NSMakePoint(0, y) toView:view width:120];
    self.osPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 360, 26)];
    for (NSString *osName in [VMStartVirtualMachine allOSTypeNames]) {
        [self.osPopup addItemWithTitle:osName];
    }
    [self.osPopup setTarget:self];
    [self.osPopup setAction:@selector(osTypeChanged:)];
    [view addSubview:self.osPopup];
    y -= 56;

    [self addLabel:AMLocalizedString(@"config.machine") at:NSMakePoint(0, y) toView:view width:120];
    self.machinePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 360, 26)];
    [self.machinePopup setTarget:self];
    [self.machinePopup setAction:@selector(machineChanged:)];
    [view addSubview:self.machinePopup];

    return view;
}

- (NSView *)buildHardwareStep {
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:self.stepContainer.bounds];
    scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSNoBorder;
    NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, self.stepContainer.bounds.size.width, 520)];
    scroll.documentView = content;
    [self.stepContainer addSubview:scroll];
    CGFloat y = content.bounds.size.height - 40;

    // CPU
    [self addLabel:AMLocalizedString(@"config.cpu") at:NSMakePoint(0, y) toView:content width:120];
    self.cpuPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 360, 26)];
    [content addSubview:self.cpuPopup];
    y -= 40;

    // CPU Sockets
    [self addLabel:@"Sockets" at:NSMakePoint(0, y) toView:content width:120];
    self.cpuSocketsPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 120, 26)];
    [self.cpuSocketsPopup addItemsWithTitles:@[@"1", @"2", @"4"]];
    [content addSubview:self.cpuSocketsPopup];
    // Cores per socket
    [self addLabel:@"Cores/Socket" at:NSMakePoint(260, y) toView:content width:90];
    self.cpuCoresPerSocketPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(360, y - 2, 80, 26)];
    [self.cpuCoresPerSocketPopup addItemsWithTitles:@[@"1", @"2", @"4", @"8", @"16"]];
    [self.cpuCoresPerSocketPopup selectItemWithTitle:@"2"];
    [content addSubview:self.cpuCoresPerSocketPopup];
    y -= 40;

    // Total CPU cores slider
    [self addLabel:AMLocalizedString(@"config.cpuCores") at:NSMakePoint(0, y) toView:content width:120];
    self.cpuSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(130, y, 300, 24)];
    self.cpuSlider.minValue = 1; self.cpuSlider.maxValue = 32; self.cpuSlider.integerValue = 2;
    self.cpuSlider.target = self; self.cpuSlider.action = @selector(cpuSliderChanged:);
    [content addSubview:self.cpuSlider];
    self.cpuLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(440, y - 2, 40, 24)];
    self.cpuLabel.bezeled = NO; self.cpuLabel.drawsBackground = NO; self.cpuLabel.editable = NO;
    self.cpuLabel.stringValue = @"2";
    self.cpuLabel.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightMedium];
    [content addSubview:self.cpuLabel];
    y -= 48;

    // Memory with slider + field
    [self addLabel:AMLocalizedString(@"config.memory") at:NSMakePoint(0, y) toView:content width:120];
    self.memorySlider = [[NSSlider alloc] initWithFrame:NSMakeRect(130, y, 250, 24)];
    self.memorySlider.minValue = 256; self.memorySlider.maxValue = 65536; self.memorySlider.integerValue = 2048;
    self.memorySlider.target = self; self.memorySlider.action = @selector(memorySliderChanged:);
    [content addSubview:self.memorySlider];
    y -= 32;
    self.memoryField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, y - 2, 120, 24)];
    self.memoryField.bezelStyle = NSTextFieldSquareBezel;
    self.memoryField.integerValue = 2048;
    self.memoryField.formatter = [self numberFormatter];
    self.memoryField.target = self; self.memoryField.action = @selector(memoryFieldChanged:);
    [content addSubview:self.memoryField];
    self.memoryUnitPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(260, y - 2, 80, 26)];
    [self.memoryUnitPopup addItemsWithTitles:[VMStartVirtualMachine supportedUnits]];
    [self.memoryUnitPopup selectItemWithTitle:@"MB"];
    [content addSubview:self.memoryUnitPopup];
    y -= 48;

    // Disk Controller (SCSI/SATA/NVMe/VirtIO)
    [self addLabel:@"Disk Controller" at:NSMakePoint(0, y) toView:content width:120];
    self.diskControllerPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 200, 26)];
    [self.diskControllerPopup addItemsWithTitles:@[@"VirtIO", @"SCSI", @"SATA", @"NVMe"]];
    [content addSubview:self.diskControllerPopup];
    y -= 40;

    // USB Version
    [self addLabel:@"USB Controller" at:NSMakePoint(0, y) toView:content width:120];
    self.usbVersionPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 200, 26)];
    [self.usbVersionPopup addItemsWithTitles:@[@"2.0 (EHCI)", @"3.0 (XHCI)", @"3.1 (XHCI)"]];
    [self.usbVersionPopup selectItemWithTitle:@"3.0 (XHCI)"];
    [content addSubview:self.usbVersionPopup];
    y -= 40;

    // Sound Card Model
    [self addLabel:@"Sound Card" at:NSMakePoint(0, y) toView:content width:120];
    self.soundCardPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 200, 26)];
    [self.soundCardPopup addItemsWithTitles:@[@"Intel HDA", @"AC97", @"ES1370 (Ensoniq)", @"Sound Blaster 16"]];
    [content addSubview:self.soundCardPopup];
    y -= 40;

    // Virtual TPM
    self.tpmCheck = [self checkboxAt:NSMakePoint(130, y) title:@"Virtual TPM (for Windows 11 / BitLocker)"];
    [content addSubview:self.tpmCheck];

    [content setFrameSize:NSMakeSize(content.bounds.size.width, 520)];
    return scroll;
}

- (NSView *)buildStorageStep {
    NSView *view = [[NSView alloc] initWithFrame:self.stepContainer.bounds];
    CGFloat y = view.bounds.size.height - 40;

    [self addLabel:AMLocalizedString(@"config.diskSize") at:NSMakePoint(0, y) toView:view width:120];
    self.diskField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, y - 2, 120, 24)];
    self.diskField.bezelStyle = NSTextFieldSquareBezel;
    self.diskField.integerValue = 20;
    self.diskField.formatter = [self numberFormatter];
    [view addSubview:self.diskField];
    self.diskUnitPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(260, y - 2, 80, 26)];
    NSMutableArray *diskUnits = [[VMStartVirtualMachine supportedUnits] mutableCopy];
    [diskUnits addObject:AMLocalizedString(@"config.noDisk")];
    [self.diskUnitPopup addItemsWithTitles:diskUnits];
    [self.diskUnitPopup selectItemWithTitle:@"GB"];
    [self.diskUnitPopup setTarget:self];
    [self.diskUnitPopup setAction:@selector(diskUnitChanged:)];
    [view addSubview:self.diskUnitPopup];
    y -= 60;

    self.useExistingDiskCheck = [[NSButton alloc] initWithFrame:NSMakeRect(130, y, 200, 22)];
    self.useExistingDiskCheck.title = AMLocalizedString(@"config.useExistingDisk");
    self.useExistingDiskCheck.buttonType = NSButtonTypeSwitch;
    self.useExistingDiskCheck.target = self; self.useExistingDiskCheck.action = @selector(existingDiskToggled:);
    [view addSubview:self.useExistingDiskCheck];
    y -= 36;

    self.existingDiskField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, y - 2, 260, 24)];
    self.existingDiskField.bezelStyle = NSTextFieldSquareBezel;
    self.existingDiskField.placeholderString = AMLocalizedString(@"config.none");
    self.existingDiskField.editable = NO;
    [view addSubview:self.existingDiskField];
    NSButton *browseBtn = [[NSButton alloc] initWithFrame:NSMakeRect(400, y - 2, 90, 24)];
    browseBtn.title = AMLocalizedString(@"config.browse");
    browseBtn.bezelStyle = NSBezelStyleRounded;
    browseBtn.target = self; browseBtn.action = @selector(browseExistingDisk:);
    [view addSubview:browseBtn];

    self.existingDiskField.hidden = !self.isNewVM;
    browseBtn.hidden = !self.isNewVM;
    self.useExistingDiskCheck.hidden = !self.isNewVM;

    return view;
}

- (NSView *)buildMediaStep {
    NSView *view = [[NSView alloc] initWithFrame:self.stepContainer.bounds];
    CGFloat y = view.bounds.size.height - 40;

    self.bootISOField = [self addFileRow:AMLocalizedString(@"config.bootISO") view:view y:&y browse:@selector(browseBootISO:) clear:@selector(clearBootISO:) extensions:@[@"iso", @"img", @"bin", @"raw"]];
    self.cdromField = [self addFileRow:AMLocalizedString(@"config.cdromImage") view:view y:&y browse:@selector(browseCDROM:) clear:@selector(clearCDROM:) extensions:@[@"iso", @"img", @"bin", @"raw"]];
    self.floppyAField = [self addFileRow:AMLocalizedString(@"config.floppyA") view:view y:&y browse:@selector(browseFloppyA:) clear:@selector(clearFloppyA:) extensions:@[@"ima", @"img", @"flp", @"dsk", @"vfd", @"bin", @"raw"]];
    self.floppyBField = [self addFileRow:AMLocalizedString(@"config.floppyB") view:view y:&y browse:@selector(browseFloppyB:) clear:@selector(clearFloppyB:) extensions:@[@"ima", @"img", @"flp", @"dsk", @"vfd", @"bin", @"raw"]];
    self.biosField = [self addFileRow:AMLocalizedString(@"config.customBIOS") view:view y:&y browse:@selector(browseBIOS:) clear:@selector(clearBIOS:) extensions:@[@"fd", @"bin", @"rom", @"efi"]];

    // ROM row
    self.romRow = [[NSView alloc] initWithFrame:NSMakeRect(0, y - 30, view.bounds.size.width, 36)];
    [view addSubview:self.romRow];
    [self addLabel:AMLocalizedString(@"config.romFile") at:NSMakePoint(0, 4) toView:self.romRow width:120];
    self.romField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, 2, 260, 24)];
    self.romField.bezelStyle = NSTextFieldSquareBezel;
    self.romField.placeholderString = AMLocalizedString(@"config.romFile.placeholder");
    self.romField.editable = NO;
    [self.romRow addSubview:self.romField];
    NSButton *romBrowse = [[NSButton alloc] initWithFrame:NSMakeRect(400, 2, 80, 24)];
    romBrowse.title = AMLocalizedString(@"config.browse");
    romBrowse.bezelStyle = NSBezelStyleRounded;
    romBrowse.target = self; romBrowse.action = @selector(browseROMFile:);
    [self.romRow addSubview:romBrowse];
    NSButton *romClear = [[NSButton alloc] initWithFrame:NSMakeRect(486, 2, 60, 24)];
    romClear.title = AMLocalizedString(@"config.clear");
    romClear.bezelStyle = NSBezelStyleRounded;
    romClear.target = self; romClear.action = @selector(clearROMFile:);
    [self.romRow addSubview:romClear];

    return view;
}

- (NSView *)buildNetworkStep {
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:self.stepContainer.bounds];
    scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSNoBorder;
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, self.stepContainer.bounds.size.width, 620)];
    scroll.documentView = view;
    [self.stepContainer addSubview:scroll];
    CGFloat y = view.bounds.size.height - 40;

    // Network mode
    [self addLabel:@"Network" at:NSMakePoint(0, y) toView:view width:120];
    self.networkPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 360, 26)];
    [self.networkPopup addItemsWithTitles:@[@"NAT (user)", @"Bridge", @"Host-only", @"Virtual Modem (dial-up)", @"Terminal", @"none"]];
    [self.networkPopup setTarget:self]; self.networkPopup.action = @selector(networkModeChanged:);
    [view addSubview:self.networkPopup];
    y -= 36;

    // Bridge interface (shown when Bridge selected)
    [self addLabel:@"Bridge NIC" at:NSMakePoint(0, y) toView:view width:120];
    self.bridgeInterfaceField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, y - 2, 200, 24)];
    self.bridgeInterfaceField.bezelStyle = NSTextFieldSquareBezel;
    self.bridgeInterfaceField.placeholderString = @"en0";
    [view addSubview:self.bridgeInterfaceField];
    self.bridgeInterfaceField.tag = 400;
    y -= 36;

    // Host-only subnet
    [self addLabel:@"Subnet" at:NSMakePoint(0, y) toView:view width:120];
    self.subnetField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, y - 2, 200, 24)];
    self.subnetField.bezelStyle = NSTextFieldSquareBezel;
    self.subnetField.stringValue = @"192.168.56.0/24";
    [view addSubview:self.subnetField];
    self.subnetField.tag = 401;
    y -= 36;

    // DHCP
    self.dhcpCheck = [self checkboxAt:NSMakePoint(130, y) title:@"Enable DHCP Server"];
    self.dhcpCheck.state = NSControlStateValueOn;
    self.dhcpCheck.tag = 402;
    [view addSubview:self.dhcpCheck];
    y -= 28;

    [self addLabel:@"DHCP Start" at:NSMakePoint(0, y) toView:view width:120];
    self.dhcpStartField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, y - 2, 160, 24)];
    self.dhcpStartField.bezelStyle = NSTextFieldSquareBezel;
    self.dhcpStartField.stringValue = @"192.168.56.100";
    [view addSubview:self.dhcpStartField];
    self.dhcpStartField.tag = 403;
    y -= 30;

    [self addLabel:@"DHCP End" at:NSMakePoint(0, y) toView:view width:120];
    self.dhcpEndField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, y - 2, 160, 24)];
    self.dhcpEndField.bezelStyle = NSTextFieldSquareBezel;
    self.dhcpEndField.stringValue = @"192.168.56.254";
    [view addSubview:self.dhcpEndField];
    self.dhcpEndField.tag = 404;
    y -= 36;

    // IPv6
    self.ipv6Check = [self checkboxAt:NSMakePoint(130, y) title:@"Enable IPv6 Support"];
    self.ipv6Check.state = NSControlStateValueOn;
    [view addSubview:self.ipv6Check];
    y -= 40;

    // Virtual modem options (Advanced mode)
    self.modemCheck = [self checkboxAt:NSMakePoint(130, y) title:@"Enable virtual modem emulation"];
    self.modemCheck.tag = 500;
    [view addSubview:self.modemCheck];
    y -= 28;

    [self addLabel:@"Modem speed" at:NSMakePoint(0, y) toView:view width:120];
    self.modemSpeedPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 200, 26)];
    [self.modemSpeedPopup addItemsWithTitles:@[@"56000 bps", @"33600 bps", @"28800 bps", @"14400 bps", @"9600 bps"]];
    self.modemSpeedPopup.tag = 501;
    [view addSubview:self.modemSpeedPopup];
    y -= 40;

    // Terminal networking (Advanced mode)
    self.terminalCheck = [self checkboxAt:NSMakePoint(130, y) title:@"Connect to host terminal (serial)"];
    self.terminalCheck.tag = 502;
    [view addSubview:self.terminalCheck];
    y -= 40;

    // Display
    [self addLabel:@"Display" at:NSMakePoint(0, y) toView:view width:120];
    self.displayPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 360, 26)];
    [self.displayPopup addItemsWithTitles:@[@"cocoa", @"none", @"vnc"]];
    [view addSubview:self.displayPopup];
    y -= 36;

    // Feature toggles
    self.accelCheck = [self checkboxAt:NSMakePoint(130, y) title:@"Hardware Acceleration"];
    self.accelCheck.state = NSControlStateValueOn;
    [view addSubview:self.accelCheck];
    y -= 28;
    self.audioCheck = [self checkboxAt:NSMakePoint(130, y) title:@"Audio"];
    self.audioCheck.state = NSControlStateValueOn;
    [view addSubview:self.audioCheck];
    y -= 28;
    self.usbCheck = [self checkboxAt:NSMakePoint(130, y) title:@"USB Support"];
    self.usbCheck.state = NSControlStateValueOn;
    [view addSubview:self.usbCheck];
    y -= 28;

    // Unity/Fusion mode
    self.unityCheck = [self checkboxAt:NSMakePoint(130, y) title:@"Unity/Fusion Mode (run VM apps alongside host)"];
    [view addSubview:self.unityCheck];
    y -= 44;

    // Shared folders section
    NSTextField *sfTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(0, y, 200, 20)];
    sfTitle.stringValue = @"Shared Folders";
    sfTitle.font = [NSFont boldSystemFontOfSize:13];
    sfTitle.textColor = [NSColor secondaryLabelColor];
    sfTitle.bezeled = NO; sfTitle.drawsBackground = NO; sfTitle.editable = NO;
    [view addSubview:sfTitle];
    y -= 100;

    self.sharedFolderScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(130, y, 360, 100)];
    self.sharedFolderScroll.borderType = NSBezelBorder;
    self.sharedFolderScroll.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    self.sharedFolderTable = [[NSTableView alloc] initWithFrame:self.sharedFolderScroll.contentView.bounds];
    self.sharedFolderTable.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.sharedFolderTable addTableColumn:[self tableColumnWithIdentifier:@"name" title:@"Name" width:120]];
    [self.sharedFolderTable addTableColumn:[self tableColumnWithIdentifier:@"hostPath" title:@"Path" width:240]];
    self.sharedFolderTable.headerView = nil;
    self.sharedFolderTable.dataSource = self;
    self.sharedFolderTable.delegate = self;
    self.sharedFolderScroll.documentView = self.sharedFolderTable;
    [view addSubview:self.sharedFolderScroll];

    NSButton *addBtn = [[NSButton alloc] initWithFrame:NSMakeRect(130, y - 32, 80, 24)];
    addBtn.title = @"Add";
    addBtn.bezelStyle = NSBezelStyleRounded;
    addBtn.target = self; addBtn.action = @selector(addSharedFolder:);
    [view addSubview:addBtn];
    NSButton *removeBtn = [[NSButton alloc] initWithFrame:NSMakeRect(220, y - 32, 80, 24)];
    removeBtn.title = @"Remove";
    removeBtn.bezelStyle = NSBezelStyleRounded;
    removeBtn.target = self; removeBtn.action = @selector(removeSharedFolder:);
    [view addSubview:removeBtn];

    // Port forwarding section
    y -= 50;
    NSTextField *pfTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(0, y, 200, 20)];
    pfTitle.stringValue = @"Port Forwarding";
    pfTitle.font = [NSFont boldSystemFontOfSize:13];
    pfTitle.textColor = [NSColor secondaryLabelColor];
    pfTitle.bezeled = NO; pfTitle.drawsBackground = NO; pfTitle.editable = NO;
    [view addSubview:pfTitle];
    y -= 28;

    [self addLabel:@"Rules" at:NSMakePoint(0, y) toView:view width:120];
    self.portForwardField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, y - 2, 260, 24)];
    self.portForwardField.bezelStyle = NSTextFieldSquareBezel;
    self.portForwardField.placeholderString = @"tcp:2222:22, tcp:8080:80";
    [view addSubview:self.portForwardField];
    NSButton *pfParseBtn = [[NSButton alloc] initWithFrame:NSMakeRect(400, y - 2, 80, 24)];
    pfParseBtn.title = @"Apply";
    pfParseBtn.bezelStyle = NSBezelStyleRounded;
    pfParseBtn.target = self; pfParseBtn.action = @selector(parsePortForwards:);
    [view addSubview:pfParseBtn];
    y -= 36;

    [view setFrameSize:NSMakeSize(view.bounds.size.width, 620 + 120)];
    [self updateNetworkStepForMode];
    return scroll;
}

- (void)networkModeChanged:(id)sender {
    NSString *mode = self.networkPopup.titleOfSelectedItem;
    BOOL isBridge = [mode containsString:@"Bridge"];
    BOOL isHostOnly = [mode containsString:@"Host-only"];
    self.bridgeInterfaceField.hidden = !isBridge;
    self.subnetField.hidden = !isHostOnly;
    self.dhcpCheck.hidden = !isHostOnly;
    self.dhcpStartField.hidden = !isHostOnly;
    self.dhcpEndField.hidden = !isHostOnly;
}

- (void)updateNetworkStepForMode {
    BOOL isAdvanced = (self.appMode == VMStartAppModeAdvanced);
    BOOL isSimple = (self.appMode == VMStartAppModeSimple);

    // Modem options - only Advanced
    NSView *modemView = [self.stepViews[@(4)] viewWithTag:500];
    NSView *modemSpeed = [self.stepViews[@(4)] viewWithTag:501];
    NSView *terminalView = [self.stepViews[@(4)] viewWithTag:502];
    if (modemView) modemView.hidden = !isAdvanced;
    if (modemSpeed) modemSpeed.hidden = !isAdvanced;
    if (terminalView) terminalView.hidden = !isAdvanced;

    // Shared folders - hide in Simple mode
    if (self.sharedFolderScroll) self.sharedFolderScroll.superview.hidden = isSimple;

    // Unity mode - Standard and Advanced only
    if (self.unityCheck) self.unityCheck.hidden = isSimple;

    // In Simple mode, limit network to NAT/bridge/none
    if (isSimple && self.networkPopup) {
        NSString *current = self.networkPopup.titleOfSelectedItem;
        [self.networkPopup removeAllItems];
        [self.networkPopup addItemsWithTitles:@[@"NAT (user)", @"Bridge", @"none"]];
        if (current && [@[@"NAT (user)", @"Bridge", @"none"] containsObject:current]) {
            [self.networkPopup selectItemWithTitle:current];
        }
    } else if (!isSimple && self.networkPopup && self.networkPopup.numberOfItems <= 3) {
        [self.networkPopup removeAllItems];
        [self.networkPopup addItemsWithTitles:@[@"NAT (user)", @"Bridge", @"Host-only", @"Virtual Modem (dial-up)", @"Terminal", @"none"]];
    }
}

- (void)updateDisplayStepForMode {
    BOOL isAdvanced = (self.appMode == VMStartAppModeAdvanced);
    BOOL isSimple = (self.appMode == VMStartAppModeSimple);

    // Simple: hide advanced features
    if (self.parallelCheck) self.parallelCheck.hidden = isSimple;
    if (self.encryptCheck) self.encryptCheck.hidden = isSimple;
    if (self.autoSnapshotCheck) self.autoSnapshotCheck.hidden = isSimple;
    if (self.autoSnapshotIntervalField) self.autoSnapshotIntervalField.hidden = isSimple;
    if (self.performancePopup) self.performancePopup.hidden = isSimple;
    if (self.hidpiCheck) self.hidpiCheck.hidden = isSimple;
    if (self.dragDropCheck) self.dragDropCheck.hidden = isSimple;

    // Standard: hide encryption and performance
    if (!isSimple && !isAdvanced) {
        if (self.encryptCheck) self.encryptCheck.hidden = YES;
        if (self.performancePopup) self.performancePopup.hidden = YES;
    }
}

- (NSView *)buildDisplayAdvancedStep {
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:self.stepContainer.bounds];
    scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSNoBorder;
    NSView *v = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, self.stepContainer.bounds.size.width, 560)];
    scroll.documentView = v;
    [self.stepContainer addSubview:scroll];
    CGFloat y = v.bounds.size.height - 40;

    // === Display Section ===
    NSTextField *secTitle1 = [[NSTextField alloc] initWithFrame:NSMakeRect(0, y, 200, 20)];
    secTitle1.stringValue = @"Display"; secTitle1.font = [NSFont boldSystemFontOfSize:13];
    secTitle1.textColor = [NSColor secondaryLabelColor];
    secTitle1.bezeled = NO; secTitle1.drawsBackground = NO; secTitle1.editable = NO;
    [v addSubview:secTitle1];
    y -= 30;

    // 3D Acceleration
    self.accel3DCheck = [self checkboxAt:NSMakePoint(20, y) title:@"3D Hardware Acceleration (OpenGL/Vulkan)"];
    [v addSubview:self.accel3DCheck];
    y -= 30;

    // VRAM slider
    [self addLabel:@"VRAM" at:NSMakePoint(0, y) toView:v width:120];
    self.vramSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(130, y, 250, 24)];
    self.vramSlider.minValue = 16; self.vramSlider.maxValue = 512; self.vramSlider.integerValue = 128;
    self.vramSlider.target = self; self.vramSlider.action = @selector(vramSliderChanged:);
    [v addSubview:self.vramSlider];
    self.vramLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(390, y - 2, 80, 24)];
    self.vramLabel.bezeled = NO; self.vramLabel.drawsBackground = NO; self.vramLabel.editable = NO;
    self.vramLabel.stringValue = @"128 MB";
    [v addSubview:self.vramLabel];
    y -= 36;

    // Multi-monitor
    [self addLabel:@"Monitors" at:NSMakePoint(0, y) toView:v width:120];
    self.monitorPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 80, 26)];
    [self.monitorPopup addItemsWithTitles:@[@"1", @"2", @"3", @"4"]];
    [v addSubview:self.monitorPopup];
    y -= 36;

    // HiDPI
    self.hidpiCheck = [self checkboxAt:NSMakePoint(20, y) title:@"HiDPI / Retina Scaling"];
    self.hidpiCheck.state = NSControlStateValueOn;
    [v addSubview:self.hidpiCheck];
    y -= 30;

    // Parallel port
    self.parallelCheck = [self checkboxAt:NSMakePoint(20, y) title:@"Parallel Port"];
    [v addSubview:self.parallelCheck];
    y -= 44;

    // === Sharing & Integration ===
    NSTextField *secTitle2 = [[NSTextField alloc] initWithFrame:NSMakeRect(0, y, 200, 20)];
    secTitle2.stringValue = @"Sharing & Integration";
    secTitle2.font = [NSFont boldSystemFontOfSize:13];
    secTitle2.textColor = [NSColor secondaryLabelColor];
    secTitle2.bezeled = NO; secTitle2.drawsBackground = NO; secTitle2.editable = NO;
    [v addSubview:secTitle2];
    y -= 30;

    self.sharedClipboardCheck = [self checkboxAt:NSMakePoint(20, y) title:@"Shared Clipboard (Host \u2194 Guest)"];
    self.sharedClipboardCheck.state = NSControlStateValueOn;
    [v addSubview:self.sharedClipboardCheck];
    y -= 28;

    self.dragDropCheck = [self checkboxAt:NSMakePoint(20, y) title:@"Drag & Drop (Host \u2194 Guest)"];
    [v addSubview:self.dragDropCheck];
    y -= 28;

    self.timeSyncCheck = [self checkboxAt:NSMakePoint(20, y) title:@"Guest Time Synchronization"];
    self.timeSyncCheck.state = NSControlStateValueOn;
    [v addSubview:self.timeSyncCheck];
    y -= 44;

    // === Snapshots & Performance ===
    NSTextField *secTitle3 = [[NSTextField alloc] initWithFrame:NSMakeRect(0, y, 200, 20)];
    secTitle3.stringValue = @"Snapshots & Performance";
    secTitle3.font = [NSFont boldSystemFontOfSize:13];
    secTitle3.textColor = [NSColor secondaryLabelColor];
    secTitle3.bezeled = NO; secTitle3.drawsBackground = NO; secTitle3.editable = NO;
    [v addSubview:secTitle3];
    y -= 30;

    self.autoSnapshotCheck = [self checkboxAt:NSMakePoint(20, y) title:@"Auto Snapshot (SmartGuard)"];
    self.autoSnapshotCheck.target = self; self.autoSnapshotCheck.action = @selector(autoSnapshotToggled:);
    [v addSubview:self.autoSnapshotCheck];
    y -= 30;

    [self addLabel:@"Interval (min)" at:NSMakePoint(0, y) toView:v width:120];
    self.autoSnapshotIntervalField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, y - 2, 80, 24)];
    self.autoSnapshotIntervalField.bezelStyle = NSTextFieldSquareBezel;
    self.autoSnapshotIntervalField.integerValue = 60;
    self.autoSnapshotIntervalField.enabled = NO;
    [v addSubview:self.autoSnapshotIntervalField];
    y -= 36;

    self.encryptCheck = [self checkboxAt:NSMakePoint(20, y) title:@"Encrypt VM (AES-256)"];
    [v addSubview:self.encryptCheck];
    y -= 36;

    [self addLabel:@"Performance" at:NSMakePoint(0, y) toView:v width:120];
    self.performancePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 200, 26)];
    [self.performancePopup addItemsWithTitles:@[@"Power Save", @"Balanced", @"High Performance"]];
    [self.performancePopup selectItemWithTitle:@"Balanced"];
    [v addSubview:self.performancePopup];

    [v setFrameSize:NSMakeSize(v.bounds.size.width, 560)];
    return scroll;
}

- (void)autoSnapshotToggled:(id)sender {
    self.autoSnapshotIntervalField.enabled = (self.autoSnapshotCheck.state == NSControlStateValueOn);
}

- (NSView *)buildSummaryStep {
    NSView *view = [[NSView alloc] initWithFrame:self.stepContainer.bounds];
    self.summaryScroll = [[NSScrollView alloc] initWithFrame:view.bounds];
    self.summaryScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.summaryScroll.borderType = NSBezelBorder;
    self.summaryView = [[NSTextView alloc] initWithFrame:self.summaryScroll.contentView.bounds];
    self.summaryView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.summaryView.editable = NO;
    self.summaryView.font = [NSFont systemFontOfSize:12];
    self.summaryView.textContainerInset = NSMakeSize(8, 8);
    self.summaryScroll.documentView = self.summaryView;
    [view addSubview:self.summaryScroll];
    [self refreshSummary];
    return view;
}

- (void)refreshSummary {
    NSString *osName = self.osPopup.titleOfSelectedItem ?: @"Other";
    NSString *machine = self.machinePopup.titleOfSelectedItem ?: @"default";
    VMStartEngineType engineType = [VMStartEngineSelector engineTypeForMachine:machine];
    NSString *engineName = [VMStartEngineSelector nameForEngineType:engineType];
    NSString *disk = [self.diskUnitPopup.titleOfSelectedItem isEqualToString:AMLocalizedString(@"config.noDisk")]
        ? AMLocalizedString(@"config.noDisk")
        : [NSString stringWithFormat:@"%ld %@", (long)self.diskField.integerValue, self.diskUnitPopup.titleOfSelectedItem];

    NSString *summary = [NSString stringWithFormat:
        @"%@: %@\n%@: %@\n%@: %@\n%@: %@\n%@: %ld\n%@: %ld %@\n%@: %@\n%@: %@\n%@: %@\n%@: %@\n%@: %@\n%@: %@\n%@: %@",
        AMLocalizedString(@"config.vmName"), self.nameField.stringValue,
        AMLocalizedString(@"config.architecture"), self.archPopup.titleOfSelectedItem,
        @"Guest OS", osName,
        AMLocalizedString(@"config.machine"), machine,
        AMLocalizedString(@"config.cpu"), self.cpuPopup.titleOfSelectedItem,
        AMLocalizedString(@"config.cpuCores"), (long)self.cpuSlider.integerValue,
        AMLocalizedString(@"config.memory"), (long)self.memoryField.integerValue, self.memoryUnitPopup.titleOfSelectedItem,
        AMLocalizedString(@"config.diskSize"), disk,
        AMLocalizedString(@"config.network"), self.networkPopup.titleOfSelectedItem,
        AMLocalizedString(@"config.display"), self.displayPopup.titleOfSelectedItem,
        AMLocalizedString(@"config.acceleration"), (self.accelCheck.state == NSControlStateValueOn) ? @"On" : @"Off",
        AMLocalizedString(@"config.audio"), (self.audioCheck.state == NSControlStateValueOn) ? @"On" : @"Off",
        AMLocalizedString(@"config.usb"), (self.usbCheck.state == NSControlStateValueOn) ? @"On" : @"Off",
        AMLocalizedString(@"config.engine"), engineName
    ];
    self.summaryView.string = summary;
}

#pragma mark - UI Helpers

- (void)addLabel:(NSString *)text at:(NSPoint)pt toView:(NSView *)view width:(CGFloat)w {
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(pt.x, pt.y, w, 22)];
    label.stringValue = text;
    label.font = [NSFont systemFontOfSize:13];
    label.alignment = NSTextAlignmentRight;
    label.bezeled = NO; label.drawsBackground = NO; label.editable = NO;
    label.textColor = [NSColor labelColor];
    [view addSubview:label];
}

- (NSButton *)checkboxAt:(NSPoint)pt title:(NSString *)title {
    NSButton *cb = [[NSButton alloc] initWithFrame:NSMakeRect(pt.x, pt.y, 360, 22)];
    cb.title = title;
    cb.buttonType = NSButtonTypeSwitch;
    return cb;
}

- (NSTextField *)addFileRow:(NSString *)label view:(NSView *)view y:(CGFloat *)y browse:(SEL)browseSel clear:(SEL)clearSel extensions:(NSArray<NSString *> *)extensions {
    [self addLabel:label at:NSMakePoint(0, *y) toView:view width:120];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(130, *y - 2, 260, 24)];
    field.bezelStyle = NSTextFieldSquareBezel;
    field.placeholderString = AMLocalizedString(@"config.none");
    field.editable = NO;
    [view addSubview:field];

    NSButton *browseBtn = [[NSButton alloc] initWithFrame:NSMakeRect(400, *y - 2, 80, 24)];
    browseBtn.title = AMLocalizedString(@"config.browse");
    browseBtn.bezelStyle = NSBezelStyleRounded;
    browseBtn.target = self; browseBtn.action = browseSel;
    [view addSubview:browseBtn];
    NSButton *clearBtn = [[NSButton alloc] initWithFrame:NSMakeRect(486, *y - 2, 60, 24)];
    clearBtn.title = AMLocalizedString(@"config.clear");
    clearBtn.bezelStyle = NSBezelStyleRounded;
    clearBtn.target = self; clearBtn.action = clearSel;
    [view addSubview:clearBtn];

    *y -= 48;
    return field;
}

- (NSTableColumn *)tableColumnWithIdentifier:(NSString *)identifier title:(NSString *)title width:(CGFloat)width {
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:identifier];
    col.title = title;
    col.width = width;
    return col;
}

- (NSNumberFormatter *)numberFormatter {
    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
    fmt.numberStyle = NSNumberFormatterDecimalStyle;
    fmt.minimum = @1;
    fmt.maximum = @999999999;
    fmt.allowsFloats = NO;
    return fmt;
}

#pragma mark - Populate

- (void)populateFields {
    self.nameField.stringValue = self.virtualMachine.name;
    NSInteger archIdx = 0;
    for (NSInteger i = 0; i < (NSInteger)self.profiles.count; i++) {
        if (self.profiles[i].architecture == self.virtualMachine.architecture) { archIdx = i; break; }
    }
    [self.archPopup selectItemAtIndex:archIdx];
    [self archChanged:nil];
    // OS type
    NSInteger osIdx = (NSInteger)self.virtualMachine.osType;
    if (osIdx >= 0 && osIdx < (NSInteger)self.osPopup.numberOfItems) {
        [self.osPopup selectItemAtIndex:osIdx];
    }
    [self.machinePopup selectItemWithTitle:self.virtualMachine.machineType];
    [self.cpuPopup selectItemWithTitle:self.virtualMachine.cpuModel];
    self.cpuSlider.integerValue = self.virtualMachine.cpuCores;
    self.cpuLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)self.virtualMachine.cpuCores];
    self.memoryField.integerValue = self.virtualMachine.memoryValue;
    [self.memoryUnitPopup selectItemWithTitle:self.virtualMachine.memoryUnit ?: @"MB"];
    self.diskField.integerValue = self.virtualMachine.diskSizeValue;
    NSString *diskUnit = self.virtualMachine.diskSizeUnit ?: @"GB";
    if ([diskUnit isEqualToString:@"none"]) {
        [self.diskUnitPopup selectItemWithTitle:AMLocalizedString(@"config.noDisk")];
        self.diskField.enabled = NO;
        self.diskField.stringValue = @"";
    } else {
        [self.diskUnitPopup selectItemWithTitle:diskUnit];
    }
    if (self.virtualMachine.bootISOPath.length > 0) self.bootISOField.stringValue = self.virtualMachine.bootISOPath;
    if (self.virtualMachine.cdromImagePath.length > 0) self.cdromField.stringValue = self.virtualMachine.cdromImagePath;
    if (self.virtualMachine.biosPath.length > 0) self.biosField.stringValue = self.virtualMachine.biosPath;
    if (self.virtualMachine.floppyAPath.length > 0) self.floppyAField.stringValue = self.virtualMachine.floppyAPath;
    if (self.virtualMachine.floppyBPath.length > 0) self.floppyBField.stringValue = self.virtualMachine.floppyBPath;
    if (self.virtualMachine.romFilePath.length > 0) self.romField.stringValue = self.virtualMachine.romFilePath;
    self.sharedFoldersList = [self.virtualMachine.sharedFolders mutableCopy] ?: [NSMutableArray array];
    [self.networkPopup selectItemWithTitle:self.virtualMachine.networkMode ?: @"NAT (user)"];
    [self.displayPopup selectItemWithTitle:self.virtualMachine.displayType];
    // Network advanced fields
    if (self.bridgeInterfaceField && self.virtualMachine.bridgeInterface.length > 0)
        self.bridgeInterfaceField.stringValue = self.virtualMachine.bridgeInterface;
    if (self.subnetField && self.virtualMachine.hostOnlySubnet.length > 0)
        self.subnetField.stringValue = self.virtualMachine.hostOnlySubnet;
    if (self.dhcpCheck) self.dhcpCheck.state = self.virtualMachine.enableDHCP ? NSControlStateValueOn : NSControlStateValueOff;
    if (self.dhcpStartField && self.virtualMachine.dhcpRangeStart.length > 0)
        self.dhcpStartField.stringValue = self.virtualMachine.dhcpRangeStart;
    if (self.dhcpEndField && self.virtualMachine.dhcpRangeEnd.length > 0)
        self.dhcpEndField.stringValue = self.virtualMachine.dhcpRangeEnd;
    if (self.ipv6Check) self.ipv6Check.state = self.virtualMachine.enableIPv6 ? NSControlStateValueOn : NSControlStateValueOff;
    [self networkModeChanged:nil]; // Update visibility
    self.accelCheck.state = self.virtualMachine.enableAcceleration ? NSControlStateValueOn : NSControlStateValueOff;
    self.audioCheck.state = self.virtualMachine.enableAudio ? NSControlStateValueOn : NSControlStateValueOff;
    self.usbCheck.state = self.virtualMachine.enableUSB ? NSControlStateValueOn : NSControlStateValueOff;
    // New hardware fields
    if (self.virtualMachine.diskController.length > 0)
        [self.diskControllerPopup selectItemWithTitle:self.virtualMachine.diskController];
    NSString *usbLabel = [NSString stringWithFormat:@"%@ (%@)",
        self.virtualMachine.usbVersion ?: @"3.0",
        [self.virtualMachine.usbVersion isEqualToString:@"2.0"] ? @"EHCI" : @"XHCI"];
    [self.usbVersionPopup selectItemWithTitle:usbLabel];
    if (self.virtualMachine.enableTPM) self.tpmCheck.state = NSControlStateValueOn;
    // Sound card
    NSDictionary *sndMap = @{@"hda": @"Intel HDA", @"ac97": @"AC97", @"es1370": @"ES1370 (Ensoniq)", @"sb16": @"Sound Blaster 16"};
    NSString *sndTitle = sndMap[self.virtualMachine.soundCardModel ?: @"hda"] ?: @"Intel HDA";
    [self.soundCardPopup selectItemWithTitle:sndTitle];
    // Memory slider sync
    if (self.memorySlider) self.memorySlider.integerValue = self.memoryField.integerValue;
    // CPU sockets/cores
    if (self.virtualMachine.cpuSockets > 0)
        [self.cpuSocketsPopup selectItemWithTitle:[NSString stringWithFormat:@"%ld", (long)self.virtualMachine.cpuSockets]];
    if (self.virtualMachine.cpuCoresPerSocket > 0)
        [self.cpuCoresPerSocketPopup selectItemWithTitle:[NSString stringWithFormat:@"%ld", (long)self.virtualMachine.cpuCoresPerSocket]];
    // Display & Advanced step
    if (self.accel3DCheck) self.accel3DCheck.state = self.virtualMachine.enable3DAcceleration ? NSControlStateValueOn : NSControlStateValueOff;
    if (self.vramSlider) { self.vramSlider.integerValue = self.virtualMachine.vramSizeMB; self.vramLabel.stringValue = [NSString stringWithFormat:@"%ld MB", (long)self.virtualMachine.vramSizeMB]; }
    if (self.monitorPopup) [self.monitorPopup selectItemWithTitle:[NSString stringWithFormat:@"%ld", (long)(self.virtualMachine.monitorCount > 0 ? self.virtualMachine.monitorCount : 1)]];
    if (self.hidpiCheck) self.hidpiCheck.state = self.virtualMachine.enableHiDPI ? NSControlStateValueOn : NSControlStateValueOff;
    if (self.parallelCheck) self.parallelCheck.state = self.virtualMachine.enableParallelPort ? NSControlStateValueOn : NSControlStateValueOff;
    if (self.sharedClipboardCheck) self.sharedClipboardCheck.state = self.virtualMachine.enableSharedClipboard ? NSControlStateValueOn : NSControlStateValueOff;
    if (self.dragDropCheck) self.dragDropCheck.state = self.virtualMachine.enableDragDrop ? NSControlStateValueOn : NSControlStateValueOff;
    if (self.timeSyncCheck) self.timeSyncCheck.state = self.virtualMachine.enableTimeSync ? NSControlStateValueOn : NSControlStateValueOff;
    if (self.autoSnapshotCheck) self.autoSnapshotCheck.state = self.virtualMachine.enableAutoSnapshot ? NSControlStateValueOn : NSControlStateValueOff;
    if (self.autoSnapshotIntervalField) self.autoSnapshotIntervalField.integerValue = self.virtualMachine.autoSnapshotInterval;
    if (self.encryptCheck) self.encryptCheck.state = self.virtualMachine.isEncrypted ? NSControlStateValueOn : NSControlStateValueOff;
    NSDictionary *perfMap = @{@"power-save": @"Power Save", @"balanced": @"Balanced", @"performance": @"High Performance"};
    if (self.performancePopup) {
        NSString *perfTitle = perfMap[self.virtualMachine.performanceProfile ?: @"balanced"] ?: @"Balanced";
        [self.performancePopup selectItemWithTitle:perfTitle];
    }
    [self updateUIForCurrentMachine];
}

- (void)archChanged:(id)sender {
    VMStartArchitectureProfile *profile = self.archPopup.selectedItem.representedObject;
    if (!profile) return;
    [self.machinePopup removeAllItems];
    [self.machinePopup addItemsWithTitles:[profile allMachines]];
    [self.cpuPopup removeAllItems];
    [self.cpuPopup addItemsWithTitles:[profile allCPUs]];
    self.accelCheck.enabled = profile.supportsAcceleration;
    if (!profile.supportsAcceleration) self.accelCheck.state = NSControlStateValueOff;
    [self updateUIForCurrentMachine];
}

- (void)machineChanged:(id)sender {
    [self updateUIForCurrentMachine];
}

- (void)osTypeChanged:(id)sender {
    if (!self.isNewVM) return; // Only apply presets for new VMs
    VMStartOSType osType = (VMStartOSType)self.osPopup.indexOfSelectedItem;
    NSDictionary *preset = [VMStartVirtualMachine presetConfigForOSType:osType];
    if (!preset) return;
    // Apply architecture
    NSInteger archVal = [preset[@"arch"] integerValue];
    for (NSInteger i = 0; i < (NSInteger)self.profiles.count; i++) {
        if (self.profiles[i].architecture == archVal) {
            [self.archPopup selectItemAtIndex:i];
            [self archChanged:nil];
            break;
        }
    }
    // Apply machine type
    NSString *machine = preset[@"machine"];
    if (machine) [self.machinePopup selectItemWithTitle:machine];
    // Apply CPU
    NSString *cpu = preset[@"cpu"];
    if (cpu && ![cpu isEqualToString:@"default"]) [self.cpuPopup selectItemWithTitle:cpu];
    NSInteger cores = [preset[@"cores"] integerValue];
    if (cores > 0) {
        self.cpuSlider.integerValue = cores;
        self.cpuLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)cores];
    }
    // Apply memory
    NSInteger memMB = [preset[@"memMB"] integerValue];
    if (memMB > 0) {
        self.memoryField.integerValue = memMB;
        [self.memoryUnitPopup selectItemWithTitle:@"MB"];
    }
    // Apply disk
    NSInteger diskGB = [preset[@"diskGB"] integerValue];
    if (diskGB > 0) {
        self.diskField.integerValue = diskGB;
        [self.diskUnitPopup selectItemWithTitle:@"GB"];
    }
    // Apply VRAM
    NSInteger vram = [preset[@"vram"] integerValue];
    if (vram > 0 && self.vramSlider) self.vramSlider.integerValue = vram;
    // Apply TPM
    BOOL tpm = [preset[@"tpm"] boolValue];
    if (tpm && self.tpmCheck) self.tpmCheck.state = NSControlStateValueOn;
    [self updateUIForCurrentMachine];
}

- (void)cpuSliderChanged:(id)sender {
    self.cpuLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)self.cpuSlider.integerValue];
}

- (void)memorySliderChanged:(id)sender {
    self.memoryField.integerValue = self.memorySlider.integerValue;
}

- (void)memoryFieldChanged:(id)sender {
    self.memorySlider.integerValue = self.memoryField.integerValue;
}

- (void)vramSliderChanged:(id)sender {
    self.vramLabel.stringValue = [NSString stringWithFormat:@"%ld MB", (long)self.vramSlider.integerValue];
}

#pragma mark - Engine Limits

- (NSInteger)fixedMemoryForMiniVMacModel:(NSString *)model {
    if ([model isEqualToString:@"Mac128K"]) return 128;
    if ([model isEqualToString:@"Mac512K"]) return 512;
    if ([model isEqualToString:@"Mac512Ke"]) return 512;
    if ([model isEqualToString:@"MacPlus"]) return 4096;
    if ([model isEqualToString:@"MacSE"]) return 4096;
    if ([model isEqualToString:@"MacSE30"]) return 4096;
    if ([model isEqualToString:@"MacClassic"]) return 4096;
    return 512;
}

- (NSDictionary *)engineUILimitsForType:(VMStartEngineType)type {
    switch (type) {
        case VMStartEngineTypeMiniVMac:
            return @{
                @"cpuCoresFixed": @YES, @"memoryFixed": @YES,
                @"networkAvailable": @NO, @"usbAvailable": @NO, @"hvfAvailable": @NO,
                @"isoAvailable": @NO, @"cdromAvailable": @NO, @"biosAvailable": @NO,
                @"sharedFoldersAvailable": @NO, @"displayBackendAvailable": @NO,
                @"romRequired": @YES, @"floppiesAvailable": @NO
            };
        case VMStartEngineTypeBasiliskII:
            return @{
                @"cpuCoresFixed": @YES, @"memoryFixed": @NO, @"memoryMaxMB": @128,
                @"networkAvailable": @YES, @"usbAvailable": @NO, @"hvfAvailable": @NO,
                @"isoAvailable": @NO, @"cdromAvailable": @YES, @"biosAvailable": @NO,
                @"sharedFoldersAvailable": @YES, @"displayBackendAvailable": @NO,
                @"romRequired": @YES, @"floppiesAvailable": @NO
            };
        case VMStartEngineTypeSheepShaver:
            return @{
                @"cpuCoresFixed": @YES, @"memoryFixed": @NO, @"memoryMaxMB": @1024,
                @"networkAvailable": @YES, @"usbAvailable": @NO, @"hvfAvailable": @NO,
                @"isoAvailable": @NO, @"cdromAvailable": @YES, @"biosAvailable": @NO,
                @"sharedFoldersAvailable": @YES, @"displayBackendAvailable": @NO,
                @"romRequired": @YES, @"floppiesAvailable": @NO
            };
        case VMStartEngineTypeDOSBox:
        case VMStartEngineTypeDOSBoxX:
            return @{
                @"cpuCoresFixed": @YES, @"memoryFixed": @NO, @"memoryMaxMB": @64,
                @"networkAvailable": @NO, @"usbAvailable": @NO, @"hvfAvailable": @NO,
                @"isoAvailable": @NO, @"cdromAvailable": @YES, @"biosAvailable": @NO,
                @"sharedFoldersAvailable": @NO, @"displayBackendAvailable": @NO,
                @"romRequired": @NO, @"floppiesAvailable": @YES
            };
        case VMStartEngineTypePCem:
            return @{
                @"cpuCoresFixed": @YES, @"memoryFixed": @NO, @"memoryMaxMB": @1024,
                @"networkAvailable": @YES, @"usbAvailable": @YES, @"hvfAvailable": @NO,
                @"isoAvailable": @YES, @"cdromAvailable": @YES, @"biosAvailable": @YES,
                @"sharedFoldersAvailable": @NO, @"displayBackendAvailable": @NO,
                @"romRequired": @NO, @"floppiesAvailable": @YES
            };
        case VMStartEngineType86Box:
            return @{
                @"cpuCoresFixed": @YES, @"memoryFixed": @NO, @"memoryMaxMB": @4096,
                @"networkAvailable": @YES, @"usbAvailable": @YES, @"hvfAvailable": @NO,
                @"isoAvailable": @YES, @"cdromAvailable": @YES, @"biosAvailable": @YES,
                @"sharedFoldersAvailable": @NO, @"displayBackendAvailable": @NO,
                @"romRequired": @NO, @"floppiesAvailable": @YES
            };
        case VMStartEngineTypeVICE:
        case VMStartEngineTypeFuse:
        case VMStartEngineTypeOpenMSX:
        case VMStartEngineTypeScummVM:
        case VMStartEngineTypeMednafen:
        case VMStartEngineTypeHatari:
        case VMStartEngineTypeARAnyM:
        case VMStartEngineTypeFSUAE:
            return @{
                @"cpuCoresFixed": @YES, @"memoryFixed": @NO, @"memoryMaxMB": @512,
                @"networkAvailable": @NO, @"usbAvailable": @NO, @"hvfAvailable": @NO,
                @"isoAvailable": @NO, @"cdromAvailable": (type == VMStartEngineTypeFSUAE ? @YES : @NO),
                @"biosAvailable": @NO, @"sharedFoldersAvailable": @NO,
                @"displayBackendAvailable": @NO, @"romRequired": @NO,
                @"floppiesAvailable": @YES
            };
        case VMStartEngineTypeQEMU:
        default:
            return @{
                @"cpuCoresFixed": @NO, @"memoryFixed": @NO,
                @"networkAvailable": @YES, @"usbAvailable": @YES, @"hvfAvailable": @YES,
                @"isoAvailable": @YES, @"cdromAvailable": @YES, @"biosAvailable": @YES,
                @"sharedFoldersAvailable": @YES, @"displayBackendAvailable": @YES,
                @"romRequired": @NO, @"floppiesAvailable": @YES
            };
    }
}

- (void)updateUIForCurrentMachine {
    NSString *machine = self.machinePopup.titleOfSelectedItem ?: @"";
    VMStartEngineType engineType = [VMStartEngineSelector engineTypeForMachine:machine];
    NSDictionary *limits = [self engineUILimitsForType:engineType];

    BOOL cpuFixed = [limits[@"cpuCoresFixed"] boolValue];
    BOOL memoryFixed = [limits[@"memoryFixed"] boolValue];
    NSInteger memoryMaxMB = [limits[@"memoryMaxMB"] integerValue];
    BOOL networkAvail = [limits[@"networkAvailable"] boolValue];
    BOOL usbAvail = [limits[@"usbAvailable"] boolValue];
    BOOL hvfAvail = [limits[@"hvfAvailable"] boolValue];
    BOOL isoAvail = [limits[@"isoAvailable"] boolValue];
    BOOL cdromAvail = [limits[@"cdromAvailable"] boolValue];
    BOOL biosAvail = [limits[@"biosAvailable"] boolValue];
    BOOL sharedAvail = [limits[@"sharedFoldersAvailable"] boolValue];
    BOOL displayAvail = [limits[@"displayBackendAvailable"] boolValue];
    BOOL romRequired = [limits[@"romRequired"] boolValue];

    if (self.romRow) self.romRow.hidden = !romRequired;
    self.cpuSlider.enabled = !cpuFixed;
    if (cpuFixed) { self.cpuSlider.integerValue = 1; self.cpuLabel.stringValue = @"1"; }

    if (memoryFixed) {
        NSInteger fixedMemKB = [self fixedMemoryForMiniVMacModel:machine];
        if (fixedMemKB >= 1024) {
            self.memoryField.integerValue = fixedMemKB / 1024;
            [self.memoryUnitPopup selectItemWithTitle:@"MB"];
        } else {
            self.memoryField.integerValue = fixedMemKB;
            [self.memoryUnitPopup selectItemWithTitle:@"KB"];
        }
        self.memoryUnitPopup.enabled = NO;
        self.memoryField.enabled = NO;
    } else {
        self.memoryField.enabled = YES;
        self.memoryUnitPopup.enabled = YES;
        NSInteger currentMB = [VMStartVirtualMachine convertValue:self.memoryField.integerValue
                                                       fromUnit:self.memoryUnitPopup.titleOfSelectedItem ?: @"MB"
                                                         toUnit:@"MB"];
        if (memoryMaxMB > 0 && currentMB > memoryMaxMB) {
            self.memoryField.integerValue = memoryMaxMB;
            [self.memoryUnitPopup selectItemWithTitle:@"MB"];
        }
    }

    self.networkPopup.enabled = networkAvail;
    if (!networkAvail) [self.networkPopup selectItemWithTitle:@"none"];
    self.usbCheck.enabled = usbAvail;
    if (!usbAvail) self.usbCheck.state = NSControlStateValueOff;
    self.accelCheck.enabled = hvfAvail;
    if (!hvfAvail) self.accelCheck.state = NSControlStateValueOff;
    self.bootISOField.enabled = isoAvail;
    self.cdromField.enabled = cdromAvail;
    if (!isoAvail) self.bootISOField.stringValue = @"";
    if (!cdromAvail) self.cdromField.stringValue = @"";
    self.biosField.enabled = biosAvail;
    if (!biosAvail) self.biosField.stringValue = @"";
    self.sharedFolderScroll.hidden = !sharedAvail;
    self.displayPopup.enabled = displayAvail;
    if (!displayAvail) [self.displayPopup selectItemWithTitle:@"none"];
}

- (void)existingDiskToggled:(id)sender {
    BOOL useExisting = self.useExistingDiskCheck.state == NSControlStateValueOn;
    BOOL noDisk = [self isNoDiskSelected];
    self.diskField.enabled = !useExisting && !noDisk;
    self.diskUnitPopup.enabled = !useExisting;
}

- (BOOL)isNoDiskSelected {
    return [self.diskUnitPopup.titleOfSelectedItem isEqualToString:AMLocalizedString(@"config.noDisk")];
}

- (void)diskUnitChanged:(id)sender {
    BOOL noDisk = [self isNoDiskSelected];
    self.diskField.enabled = !noDisk;
    if (noDisk) self.diskField.stringValue = @"";
}

#pragma mark - File Pickers

- (void)openFilePickerForField:(NSTextField *)field extensions:(NSArray<NSString *> *)extensions title:(NSString *)title {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES; panel.canChooseDirectories = NO; panel.allowsMultipleSelection = NO;
    panel.title = title;
    if (extensions.count > 0) {
        NSMutableArray *types = [NSMutableArray array];
        for (NSString *ext in extensions) {
            if (@available(macOS 11.0, *)) {
                UTType *type = [UTType typeWithFilenameExtension:ext];
                if (type) [types addObject:type];
            }
        }
        panel.allowedContentTypes = types;
        panel.allowsOtherFileTypes = YES;
    }
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK && panel.URL) field.stringValue = panel.URL.path;
    }];
}

- (void)browseBootISO:(id)sender { [self openFilePickerForField:self.bootISOField extensions:@[@"iso", @"img", @"bin", @"raw"] title:AMLocalizedString(@"config.bootISO")]; }
- (void)clearBootISO:(id)sender { self.bootISOField.stringValue = @""; }
- (void)browseCDROM:(id)sender { [self openFilePickerForField:self.cdromField extensions:@[@"iso", @"img", @"bin", @"raw"] title:AMLocalizedString(@"config.cdromImage")]; }
- (void)clearCDROM:(id)sender { self.cdromField.stringValue = @""; }
- (void)browseBIOS:(id)sender { [self openFilePickerForField:self.biosField extensions:@[@"fd", @"bin", @"rom", @"efi"] title:AMLocalizedString(@"config.customBIOS")]; }
- (void)clearBIOS:(id)sender { self.biosField.stringValue = @""; }
- (void)browseExistingDisk:(id)sender { [self openFilePickerForField:self.existingDiskField extensions:@[@"qcow2", @"raw", @"img", @"vmdk", @"vdi", @"vhd", @"vhdx"] title:AMLocalizedString(@"config.useExistingDisk")]; }
- (void)browseFloppyA:(id)sender { [self openFilePickerForField:self.floppyAField extensions:@[@"ima", @"img", @"flp", @"dsk", @"vfd", @"bin", @"raw"] title:AMLocalizedString(@"config.floppyA")]; }
- (void)clearFloppyA:(id)sender { self.floppyAField.stringValue = @""; }
- (void)browseFloppyB:(id)sender { [self openFilePickerForField:self.floppyBField extensions:@[@"ima", @"img", @"flp", @"dsk", @"vfd", @"bin", @"raw"] title:AMLocalizedString(@"config.floppyB")]; }
- (void)clearFloppyB:(id)sender { self.floppyBField.stringValue = @""; }
- (void)browseROMFile:(id)sender { [self openFilePickerForField:self.romField extensions:@[@"rom", @"bin", @"ROM"] title:AMLocalizedString(@"config.romFile")]; }
- (void)clearROMFile:(id)sender { self.romField.stringValue = @""; }

#pragma mark - Shared Folders

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return self.sharedFoldersList.count; }

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= (NSInteger)self.sharedFoldersList.count) return @"";
    NSDictionary *folder = self.sharedFoldersList[row];
    return [tableColumn.identifier isEqualToString:@"name"] ? (folder[@"name"] ?: @"") : (folder[@"hostPath"] ?: @"");
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= (NSInteger)self.sharedFoldersList.count) return;
    NSMutableDictionary *folder = [self.sharedFoldersList[row] mutableCopy];
    folder[tableColumn.identifier] = object ?: @"";
    self.sharedFoldersList[row] = folder;
}

- (void)addSharedFolder:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO; panel.canChooseDirectories = YES; panel.allowsMultipleSelection = NO;
    panel.title = AMLocalizedString(@"config.selectFolder");
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK && panel.URL) {
            NSString *path = panel.URL.path;
            [self.sharedFoldersList addObject:@{@"name": [path lastPathComponent], @"hostPath": path, @"readonly": @(NO)}];
            [self.sharedFolderTable reloadData];
        }
    }];
}

- (void)removeSharedFolder:(id)sender {
    NSInteger row = self.sharedFolderTable.selectedRow;
    if (row >= 0 && row < (NSInteger)self.sharedFoldersList.count) {
        [self.sharedFoldersList removeObjectAtIndex:row];
        [self.sharedFolderTable reloadData];
    }
}

- (void)parsePortForwards:(id)sender {
    NSString *input = self.portForwardField.stringValue;
    NSMutableArray *rules = [NSMutableArray array];
    NSArray *parts = [input componentsSeparatedByString:@","];
    for (NSString *part in parts) {
        NSString *rule = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSArray *components = [rule componentsSeparatedByString:@":"];
        if (components.count >= 3) {
            [rules addObject:@{
                @"proto": components[0],
                @"hostPort": components[1],
                @"guestPort": components[2],
                @"guestIP": components.count > 3 ? components[3] : @""
            }];
        }
    }
    self.virtualMachine.portForwards = rules;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Port Forwarding";
    alert.informativeText = [NSString stringWithFormat:@"Parsed %lu port forwarding rule%@.", (unsigned long)rules.count, rules.count != 1 ? @"s" : @""];
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

#pragma mark - Save

- (void)saveConfig:(id)sender {
    self.virtualMachine.name = self.nameField.stringValue ?: AMLocalizedString(@"library.newVMName");
    VMStartArchitectureProfile *profile = self.archPopup.selectedItem.representedObject;
    if (profile) self.virtualMachine.architecture = profile.architecture;
    self.virtualMachine.osType = (VMStartOSType)self.osPopup.indexOfSelectedItem;
    NSString *machine = self.machinePopup.titleOfSelectedItem ?: @"default";
    self.virtualMachine.machineType = machine;
    self.virtualMachine.cpuModel = self.cpuPopup.titleOfSelectedItem ?: @"default";

    VMStartEngineType engineType = [VMStartEngineSelector engineTypeForMachine:machine];
    NSDictionary *limits = [self engineUILimitsForType:engineType];
    BOOL cpuFixed = [limits[@"cpuCoresFixed"] boolValue];
    BOOL memoryFixed = [limits[@"memoryFixed"] boolValue];
    NSInteger memoryMaxMB = [limits[@"memoryMaxMB"] integerValue];
    BOOL networkAvail = [limits[@"networkAvailable"] boolValue];
    BOOL usbAvail = [limits[@"usbAvailable"] boolValue];
    BOOL hvfAvail = [limits[@"hvfAvailable"] boolValue];
    BOOL isoAvail = [limits[@"isoAvailable"] boolValue];
    BOOL cdromAvail = [limits[@"cdromAvailable"] boolValue];
    BOOL biosAvail = [limits[@"biosAvailable"] boolValue];
    BOOL sharedAvail = [limits[@"sharedFoldersAvailable"] boolValue];
    BOOL displayAvail = [limits[@"displayBackendAvailable"] boolValue];

    self.virtualMachine.cpuCores = cpuFixed ? 1 : self.cpuSlider.integerValue;
    NSInteger memVal = self.memoryField.integerValue;
    NSString *memUnit = self.memoryUnitPopup.titleOfSelectedItem ?: @"MB";
    if (memoryFixed) {
        NSInteger fixedMemKB = [self fixedMemoryForMiniVMacModel:machine];
        if (fixedMemKB >= 1024) { memVal = fixedMemKB / 1024; memUnit = @"MB"; }
        else { memVal = fixedMemKB; memUnit = @"KB"; }
    } else if (memoryMaxMB > 0) {
        NSInteger memMB = [VMStartVirtualMachine convertValue:memVal fromUnit:memUnit toUnit:@"MB"];
        if (memMB > memoryMaxMB) { memVal = memoryMaxMB; memUnit = @"MB"; }
        if (memMB < 1) { memVal = 1; memUnit = @"MB"; }
    }
    self.virtualMachine.memoryValue = memVal;
    self.virtualMachine.memoryUnit = memUnit;

    self.virtualMachine.diskSizeValue = self.diskField.integerValue;
    if ([self isNoDiskSelected]) {
        self.virtualMachine.diskSizeUnit = @"none";
        self.virtualMachine.diskSizeValue = 0;
    } else {
        self.virtualMachine.diskSizeUnit = self.diskUnitPopup.titleOfSelectedItem ?: @"GB";
    }

    NSString *bootISO = isoAvail ? self.bootISOField.stringValue : @"";
    self.virtualMachine.bootISOPath = bootISO.length > 0 ? bootISO : @"";
    NSString *cdrom = cdromAvail ? self.cdromField.stringValue : @"";
    self.virtualMachine.cdromImagePath = cdrom.length > 0 ? cdrom : @"";
    NSString *bios = biosAvail ? self.biosField.stringValue : @"";
    self.virtualMachine.biosPath = bios.length > 0 ? bios : @"";
    self.virtualMachine.floppyAPath = self.floppyAField.stringValue.length > 0 ? self.floppyAField.stringValue : @"";
    self.virtualMachine.floppyBPath = self.floppyBField.stringValue.length > 0 ? self.floppyBField.stringValue : @"";
    self.virtualMachine.romFilePath = self.romField.stringValue.length > 0 ? self.romField.stringValue : @"";
    self.virtualMachine.sharedFolders = sharedAvail ? ([self.sharedFoldersList copy] ?: @[]) : @[];

    NSString *netMode = networkAvail ? self.networkPopup.titleOfSelectedItem : @"none";
    if ([netMode containsString:@"Bridge"]) self.virtualMachine.networkMode = @"bridge";
    else if ([netMode containsString:@"Host-only"]) self.virtualMachine.networkMode = @"host-only";
    else if ([netMode containsString:@"Modem"]) self.virtualMachine.networkMode = @"modem";
    else if ([netMode containsString:@"Terminal"]) self.virtualMachine.networkMode = @"terminal";
    else if ([netMode containsString:@"none"]) self.virtualMachine.networkMode = @"none";
    else self.virtualMachine.networkMode = @"user";
    self.virtualMachine.displayType = displayAvail ? (self.displayPopup.titleOfSelectedItem ?: @"cocoa") : @"none";
    self.virtualMachine.enableAcceleration = hvfAvail ? (self.accelCheck.state == NSControlStateValueOn) : NO;
    self.virtualMachine.enableAudio = self.audioCheck.state == NSControlStateValueOn;
    self.virtualMachine.enableUSB = usbAvail ? (self.usbCheck.state == NSControlStateValueOn) : NO;

    // New hardware properties
    self.virtualMachine.diskController = self.diskControllerPopup.titleOfSelectedItem ?: @"VirtIO";
    NSString *usbSel = self.usbVersionPopup.titleOfSelectedItem ?: @"3.0";
    if ([usbSel containsString:@"2.0"]) self.virtualMachine.usbVersion = @"2.0";
    else if ([usbSel containsString:@"3.1"]) self.virtualMachine.usbVersion = @"3.1";
    else self.virtualMachine.usbVersion = @"3.0";
    self.virtualMachine.enableTPM = (self.tpmCheck.state == NSControlStateValueOn);
    NSDictionary *sndRevMap = @{@"Intel HDA": @"hda", @"AC97": @"ac97", @"ES1370 (Ensoniq)": @"es1370", @"Sound Blaster 16": @"sb16"};
    self.virtualMachine.soundCardModel = sndRevMap[self.soundCardPopup.titleOfSelectedItem] ?: @"hda";
    self.virtualMachine.enableSoundCard = YES;
    self.virtualMachine.cpuSockets = [self.cpuSocketsPopup.titleOfSelectedItem integerValue];
    if (self.virtualMachine.cpuSockets == 0) self.virtualMachine.cpuSockets = 1;
    self.virtualMachine.cpuCoresPerSocket = [self.cpuCoresPerSocketPopup.titleOfSelectedItem integerValue];
    if (self.virtualMachine.cpuCoresPerSocket == 0) self.virtualMachine.cpuCoresPerSocket = self.cpuSlider.integerValue;

    // Display & Advanced
    self.virtualMachine.enable3DAcceleration = (self.accel3DCheck && self.accel3DCheck.state == NSControlStateValueOn);
    self.virtualMachine.vramSizeMB = self.vramSlider ? self.vramSlider.integerValue : 128;
    self.virtualMachine.monitorCount = self.monitorPopup ? [self.monitorPopup.titleOfSelectedItem integerValue] : 1;
    self.virtualMachine.enableHiDPI = (self.hidpiCheck && self.hidpiCheck.state == NSControlStateValueOn);
    self.virtualMachine.enableParallelPort = (self.parallelCheck && self.parallelCheck.state == NSControlStateValueOn);
    self.virtualMachine.enableSharedClipboard = (self.sharedClipboardCheck && self.sharedClipboardCheck.state == NSControlStateValueOn);
    self.virtualMachine.enableDragDrop = (self.dragDropCheck && self.dragDropCheck.state == NSControlStateValueOn);
    self.virtualMachine.enableTimeSync = (self.timeSyncCheck && self.timeSyncCheck.state == NSControlStateValueOn);
    self.virtualMachine.enableAutoSnapshot = (self.autoSnapshotCheck && self.autoSnapshotCheck.state == NSControlStateValueOn);
    self.virtualMachine.autoSnapshotInterval = self.autoSnapshotIntervalField ? self.autoSnapshotIntervalField.integerValue : 60;
    self.virtualMachine.isEncrypted = (self.encryptCheck && self.encryptCheck.state == NSControlStateValueOn);
    NSDictionary *perfRevMap = @{@"Power Save": @"power-save", @"Balanced": @"balanced", @"High Performance": @"performance"};
    self.virtualMachine.performanceProfile = perfRevMap[self.performancePopup.titleOfSelectedItem] ?: @"balanced";

    // Network advanced properties
    if (self.bridgeInterfaceField) self.virtualMachine.bridgeInterface = self.bridgeInterfaceField.stringValue ?: @"";
    if (self.subnetField) self.virtualMachine.hostOnlySubnet = self.subnetField.stringValue ?: @"192.168.56.0/24";
    if (self.dhcpCheck) self.virtualMachine.enableDHCP = (self.dhcpCheck.state == NSControlStateValueOn);
    if (self.dhcpStartField) self.virtualMachine.dhcpRangeStart = self.dhcpStartField.stringValue ?: @"192.168.56.100";
    if (self.dhcpEndField) self.virtualMachine.dhcpRangeEnd = self.dhcpEndField.stringValue ?: @"192.168.56.254";
    if (self.ipv6Check) self.virtualMachine.enableIPv6 = (self.ipv6Check.state == NSControlStateValueOn);

    if (self.isNewVM) {
        NSString *dir = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject]
                         stringByAppendingPathComponent:@"VMStart/VirtualMachines"];
        NSString *vmPath = [dir stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"%@.vmstart", self.virtualMachine.vmIdentifier]];
        self.virtualMachine.vmBundlePath = vmPath;
        BOOL noDisk = [self.virtualMachine.diskSizeUnit isEqualToString:@"none"];
        BOOL useExisting = self.useExistingDiskCheck.state == NSControlStateValueOn && self.existingDiskField.stringValue.length > 0;
        if (noDisk) {
            self.virtualMachine.diskImagePath = @"";
        } else if (useExisting) {
            NSString *srcPath = self.existingDiskField.stringValue;
            NSString *dstPath = [vmPath stringByAppendingPathComponent:@"disk.qcow2"];
            NSFileManager *fm = [NSFileManager defaultManager];
            [fm createDirectoryAtPath:vmPath withIntermediateDirectories:YES attributes:nil error:nil];
            NSError *err = nil;
            [fm copyItemAtPath:srcPath toPath:dstPath error:&err];
            self.virtualMachine.diskImagePath = err ? srcPath : dstPath;
        } else {
            NSString *sizeStr = [self.virtualMachine diskSizeForQEMU];
            if (sizeStr.length > 0) {
                NSString *diskPath = [vmPath stringByAppendingPathComponent:@"disk.qcow2"];
                self.virtualMachine.diskImagePath = diskPath;
                [self createDiskImageAtPath:diskPath sizeString:sizeStr];
            } else {
                self.virtualMachine.diskImagePath = @"";
            }
        }
    }
    [self.delegate configDidSaveVM:self.virtualMachine];
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (void)createDiskImageAtPath:(NSString *)path sizeString:(NSString *)sizeStr {
    NSString *qemuImg = @"/opt/homebrew/bin/qemu-img";
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:qemuImg]) qemuImg = @"/usr/local/bin/qemu-img";
    if (![fm fileExistsAtPath:qemuImg]) return;
    NSString *dir = [path stringByDeletingLastPathComponent];
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:qemuImg];
    task.arguments = @[@"create", @"-f", @"qcow2", path, sizeStr];
    [task launch];
    [task waitUntilExit];
}

- (void)cancelConfig:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

@end