//
//  VMNexusVirtualMachine.m
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusVirtualMachine.h"
#import "VMNexusLocalization.h"
#import <AppKit/AppKit.h>

static NSString *const kVMConfigFileName = @"vm.json";

@implementation VMNexusVirtualMachine

+ (BOOL)supportsSecureCoding { return YES; }

+ (instancetype)virtualMachineWithName:(NSString *)name architecture:(VMNexusArchitecture)arch {
    VMNexusVirtualMachine *vm = [[VMNexusVirtualMachine alloc] init];
    vm.name = name;
    vm.vmIdentifier = [[NSUUID UUID] UUIDString];
    vm.architecture = arch;
    vm.machineType = @"default";
    vm.cpuModel = @"default";
    vm.cpuCores = 2;
    vm.memoryValue = 2048;
    vm.memoryUnit = @"MB";
    vm.diskSizeValue = 20;
    vm.diskSizeUnit = @"GB";
    vm.status = VMNexusStatusStopped;
    vm.networkMode = @"user";
    vm.displayType = @"cocoa";
    vm.enableAudio = YES;
    vm.enableUSB = YES;
    vm.enableAcceleration = YES;
    vm.biosPath = @"";
    vm.additionalArgs = @[];
    vm.sharedFolders = @[];
    vm.vncPort = 0;
    vm.notes = @"";
    vm.createdAt = [NSDate date];
    vm.lastUsedAt = [NSDate date];
    // Enhanced defaults
    vm.diskController = @"VirtIO";
    vm.usbVersion = @"3.0";
    vm.enableTPM = NO;
    vm.enable3DAcceleration = NO;
    vm.vramSizeMB = 128;
    vm.monitorCount = 1;
    vm.enableHiDPI = YES;
    vm.enableParallelPort = NO;
    vm.enableSoundCard = YES;
    vm.soundCardModel = @"hda";
    vm.cpuSockets = 1;
    vm.cpuCoresPerSocket = 2;
    vm.enableSharedClipboard = YES;
    vm.enableDragDrop = NO;
    vm.enableTimeSync = YES;
    vm.performanceProfile = @"balanced";
    vm.snapshots = @[];
    vm.enableAutoSnapshot = NO;
    vm.autoSnapshotInterval = 60;
    vm.isEncrypted = NO;
    vm.isFavorite = NO;
    vm.group = @"";
    vm.portForwards = @[];
    vm.bridgeInterface = @"";
    vm.hostOnlySubnet = @"192.168.56.0/24";
    vm.enableDHCP = YES;
    vm.dhcpRangeStart = @"192.168.56.100";
    vm.dhcpRangeEnd = @"192.168.56.254";
    vm.enableIPv6 = YES;
    return vm;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.vmIdentifier forKey:@"vmIdentifier"];
    [coder encodeInteger:self.architecture forKey:@"architecture"];
    [coder encodeObject:self.machineType forKey:@"machineType"];
    [coder encodeObject:self.cpuModel forKey:@"cpuModel"];
    [coder encodeInteger:self.cpuCores forKey:@"cpuCores"];
    [coder encodeInteger:self.memoryValue forKey:@"memoryValue"];
    [coder encodeObject:self.memoryUnit forKey:@"memoryUnit"];
    [coder encodeObject:self.diskImagePath forKey:@"diskImagePath"];
    [coder encodeInteger:self.diskSizeValue forKey:@"diskSizeValue"];
    [coder encodeObject:self.diskSizeUnit forKey:@"diskSizeUnit"];
    [coder encodeObject:self.cdromImagePath forKey:@"cdromImagePath"];
    [coder encodeObject:self.bootISOPath forKey:@"bootISOPath"];
    [coder encodeObject:self.floppyAPath forKey:@"floppyAPath"];
    [coder encodeObject:self.floppyBPath forKey:@"floppyBPath"];
    [coder encodeObject:self.sharedFolders forKey:@"sharedFolders"];
    [coder encodeObject:self.romFilePath forKey:@"romFilePath"];
    [coder encodeObject:self.classicMacModel forKey:@"classicMacModel"];
    [coder encodeObject:self.networkMode forKey:@"networkMode"];
    [coder encodeObject:self.displayType forKey:@"displayType"];
    [coder encodeBool:self.enableAudio forKey:@"enableAudio"];
    [coder encodeBool:self.enableUSB forKey:@"enableUSB"];
    [coder encodeBool:self.enableAcceleration forKey:@"enableAcceleration"];
    [coder encodeObject:self.biosPath forKey:@"biosPath"];
    [coder encodeObject:self.additionalArgs forKey:@"additionalArgs"];
    [coder encodeInteger:self.vncPort forKey:@"vncPort"];
    [coder encodeObject:self.notes forKey:@"notes"];
    [coder encodeObject:self.createdAt forKey:@"createdAt"];
    [coder encodeObject:self.lastUsedAt forKey:@"lastUsedAt"];
    // Enhanced properties
    [coder encodeObject:self.diskController forKey:@"diskController"];
    [coder encodeObject:self.usbVersion forKey:@"usbVersion"];
    [coder encodeBool:self.enableTPM forKey:@"enableTPM"];
    [coder encodeBool:self.enable3DAcceleration forKey:@"enable3DAcceleration"];
    [coder encodeInteger:self.vramSizeMB forKey:@"vramSizeMB"];
    [coder encodeInteger:self.monitorCount forKey:@"monitorCount"];
    [coder encodeBool:self.enableHiDPI forKey:@"enableHiDPI"];
    [coder encodeBool:self.enableParallelPort forKey:@"enableParallelPort"];
    [coder encodeBool:self.enableSoundCard forKey:@"enableSoundCard"];
    [coder encodeObject:self.soundCardModel forKey:@"soundCardModel"];
    [coder encodeInteger:self.cpuSockets forKey:@"cpuSockets"];
    [coder encodeInteger:self.cpuCoresPerSocket forKey:@"cpuCoresPerSocket"];
    [coder encodeBool:self.enableSharedClipboard forKey:@"enableSharedClipboard"];
    [coder encodeBool:self.enableDragDrop forKey:@"enableDragDrop"];
    [coder encodeBool:self.enableTimeSync forKey:@"enableTimeSync"];
    [coder encodeObject:self.performanceProfile forKey:@"performanceProfile"];
    [coder encodeObject:self.snapshots forKey:@"snapshots"];
    [coder encodeBool:self.enableAutoSnapshot forKey:@"enableAutoSnapshot"];
    [coder encodeInteger:self.autoSnapshotInterval forKey:@"autoSnapshotInterval"];
    [coder encodeBool:self.isEncrypted forKey:@"isEncrypted"];
    [coder encodeObject:self.encryptionKeyHash forKey:@"encryptionKeyHash"];
    [coder encodeBool:self.isFavorite forKey:@"isFavorite"];
    [coder encodeObject:self.group forKey:@"group"];
    [coder encodeObject:self.portForwards forKey:@"portForwards"];
    [coder encodeObject:self.bridgeInterface forKey:@"bridgeInterface"];
    [coder encodeObject:self.hostOnlySubnet forKey:@"hostOnlySubnet"];
    [coder encodeBool:self.enableDHCP forKey:@"enableDHCP"];
    [coder encodeObject:self.dhcpRangeStart forKey:@"dhcpRangeStart"];
    [coder encodeObject:self.dhcpRangeEnd forKey:@"dhcpRangeEnd"];
    [coder encodeBool:self.enableIPv6 forKey:@"enableIPv6"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
        _vmIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"vmIdentifier"];
        _architecture = [coder decodeIntegerForKey:@"architecture"];
        _machineType = [coder decodeObjectOfClass:[NSString class] forKey:@"machineType"];
        _cpuModel = [coder decodeObjectOfClass:[NSString class] forKey:@"cpuModel"];
        _cpuCores = [coder decodeIntegerForKey:@"cpuCores"];
        _memoryValue = [coder decodeIntegerForKey:@"memoryValue"];
        _memoryUnit = [coder decodeObjectOfClass:[NSString class] forKey:@"memoryUnit"] ?: @"MB";
        // backward compat
        if ([coder containsValueForKey:@"memoryMB"] && _memoryValue == 0) {
            _memoryValue = [coder decodeIntegerForKey:@"memoryMB"];
            _memoryUnit = @"MB";
        }
        _diskImagePath = [coder decodeObjectOfClass:[NSString class] forKey:@"diskImagePath"];
        _diskSizeValue = [coder decodeIntegerForKey:@"diskSizeValue"];
        _diskSizeUnit = [coder decodeObjectOfClass:[NSString class] forKey:@"diskSizeUnit"] ?: @"GB";
        if ([coder containsValueForKey:@"diskSizeGB"] && _diskSizeValue == 0) {
            _diskSizeValue = [coder decodeIntegerForKey:@"diskSizeGB"];
            _diskSizeUnit = @"GB";
        }
        _cdromImagePath = [coder decodeObjectOfClass:[NSString class] forKey:@"cdromImagePath"];
        _bootISOPath = [coder decodeObjectOfClass:[NSString class] forKey:@"bootISOPath"];
        _floppyAPath = [coder decodeObjectOfClass:[NSString class] forKey:@"floppyAPath"];
        _floppyBPath = [coder decodeObjectOfClass:[NSString class] forKey:@"floppyBPath"];
        _sharedFolders = [coder decodeObjectOfClass:[NSArray class] forKey:@"sharedFolders"] ?: @[];
        _romFilePath = [coder decodeObjectOfClass:[NSString class] forKey:@"romFilePath"];
        _classicMacModel = [coder decodeObjectOfClass:[NSString class] forKey:@"classicMacModel"];
        _networkMode = [coder decodeObjectOfClass:[NSString class] forKey:@"networkMode"];
        _displayType = [coder decodeObjectOfClass:[NSString class] forKey:@"displayType"];
        _enableAudio = [coder decodeBoolForKey:@"enableAudio"];
        _enableUSB = [coder decodeBoolForKey:@"enableUSB"];
        _enableAcceleration = [coder decodeBoolForKey:@"enableAcceleration"];
        _biosPath = [coder decodeObjectOfClass:[NSString class] forKey:@"biosPath"];
        _additionalArgs = [coder decodeObjectOfClass:[NSArray class] forKey:@"additionalArgs"];
        _vncPort = [coder decodeIntegerForKey:@"vncPort"];
        _notes = [coder decodeObjectOfClass:[NSString class] forKey:@"notes"];
        _createdAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"createdAt"];
        _lastUsedAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"lastUsedAt"];
        // Enhanced properties
        _diskController = [coder decodeObjectOfClass:[NSString class] forKey:@"diskController"] ?: @"VirtIO";
        _usbVersion = [coder decodeObjectOfClass:[NSString class] forKey:@"usbVersion"] ?: @"3.0";
        _enableTPM = [coder decodeBoolForKey:@"enableTPM"];
        _enable3DAcceleration = [coder decodeBoolForKey:@"enable3DAcceleration"];
        _vramSizeMB = [coder decodeIntegerForKey:@"vramSizeMB"];
        if (_vramSizeMB == 0) _vramSizeMB = 128;
        _monitorCount = [coder decodeIntegerForKey:@"monitorCount"];
        if (_monitorCount == 0) _monitorCount = 1;
        _enableHiDPI = [coder decodeBoolForKey:@"enableHiDPI"];
        _enableParallelPort = [coder decodeBoolForKey:@"enableParallelPort"];
        _enableSoundCard = [coder decodeBoolForKey:@"enableSoundCard"];
        _soundCardModel = [coder decodeObjectOfClass:[NSString class] forKey:@"soundCardModel"] ?: @"hda";
        _cpuSockets = [coder decodeIntegerForKey:@"cpuSockets"];
        if (_cpuSockets == 0) _cpuSockets = 1;
        _cpuCoresPerSocket = [coder decodeIntegerForKey:@"cpuCoresPerSocket"];
        if (_cpuCoresPerSocket == 0) _cpuCoresPerSocket = _cpuCores;
        _enableSharedClipboard = [coder decodeBoolForKey:@"enableSharedClipboard"];
        _enableDragDrop = [coder decodeBoolForKey:@"enableDragDrop"];
        _enableTimeSync = [coder decodeBoolForKey:@"enableTimeSync"];
        _performanceProfile = [coder decodeObjectOfClass:[NSString class] forKey:@"performanceProfile"] ?: @"balanced";
        _snapshots = [coder decodeObjectOfClass:[NSArray class] forKey:@"snapshots"] ?: @[];
        _enableAutoSnapshot = [coder decodeBoolForKey:@"enableAutoSnapshot"];
        _autoSnapshotInterval = [coder decodeIntegerForKey:@"autoSnapshotInterval"];
        if (_autoSnapshotInterval == 0) _autoSnapshotInterval = 60;
        _isEncrypted = [coder decodeBoolForKey:@"isEncrypted"];
        _encryptionKeyHash = [coder decodeObjectOfClass:[NSString class] forKey:@"encryptionKeyHash"];
        _isFavorite = [coder decodeBoolForKey:@"isFavorite"];
        _group = [coder decodeObjectOfClass:[NSString class] forKey:@"group"] ?: @"";
        _portForwards = [coder decodeObjectOfClass:[NSArray class] forKey:@"portForwards"] ?: @[];
        _bridgeInterface = [coder decodeObjectOfClass:[NSString class] forKey:@"bridgeInterface"] ?: @"";
        _hostOnlySubnet = [coder decodeObjectOfClass:[NSString class] forKey:@"hostOnlySubnet"] ?: @"192.168.56.0/24";
        _enableDHCP = [coder decodeBoolForKey:@"enableDHCP"];
        _dhcpRangeStart = [coder decodeObjectOfClass:[NSString class] forKey:@"dhcpRangeStart"] ?: @"192.168.56.100";
        _dhcpRangeEnd = [coder decodeObjectOfClass:[NSString class] forKey:@"dhcpRangeEnd"] ?: @"192.168.56.254";
        _enableIPv6 = [coder decodeBoolForKey:@"enableIPv6"];
        _status = VMNexusStatusStopped;
    }
    return self;
}

#pragma mark - Bundle I/O

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"name"] = self.name ?: @"";
    dict[@"identifier"] = self.vmIdentifier ?: @"";
    dict[@"architecture"] = @(self.architecture);
    dict[@"osType"] = @(self.osType);
    dict[@"machineType"] = self.machineType ?: @"default";
    dict[@"cpuModel"] = self.cpuModel ?: @"default";
    dict[@"cpuCores"] = @(self.cpuCores);
    dict[@"memoryValue"] = @(self.memoryValue);
    dict[@"memoryUnit"] = self.memoryUnit ?: @"MB";
    dict[@"diskImagePath"] = self.diskImagePath ?: @"";
    dict[@"diskSizeValue"] = @(self.diskSizeValue);
    dict[@"diskSizeUnit"] = self.diskSizeUnit ?: @"GB";
    dict[@"cdromImagePath"] = self.cdromImagePath ?: @"";
    dict[@"bootISOPath"] = self.bootISOPath ?: @"";
    dict[@"floppyAPath"] = self.floppyAPath ?: @"";
    dict[@"floppyBPath"] = self.floppyBPath ?: @"";
    dict[@"sharedFolders"] = self.sharedFolders ?: @[];
    dict[@"romFilePath"] = self.romFilePath ?: @"";
    dict[@"classicMacModel"] = self.classicMacModel ?: @"";
    dict[@"networkMode"] = self.networkMode ?: @"user";
    dict[@"displayType"] = self.displayType ?: @"cocoa";
    dict[@"enableAudio"] = @(self.enableAudio);
    dict[@"enableUSB"] = @(self.enableUSB);
    dict[@"enableAcceleration"] = @(self.enableAcceleration);
    dict[@"biosPath"] = self.biosPath ?: @"";
    dict[@"additionalArgs"] = self.additionalArgs ?: @[];
    dict[@"vncPort"] = @(self.vncPort);
    dict[@"notes"] = self.notes ?: @"";
    dict[@"createdAt"] = @([self.createdAt timeIntervalSince1970]);
    dict[@"lastUsedAt"] = @([self.lastUsedAt timeIntervalSince1970]);
    // Enhanced
    dict[@"diskController"] = self.diskController ?: @"VirtIO";
    dict[@"usbVersion"] = self.usbVersion ?: @"3.0";
    dict[@"enableTPM"] = @(self.enableTPM);
    dict[@"enable3DAcceleration"] = @(self.enable3DAcceleration);
    dict[@"vramSizeMB"] = @(self.vramSizeMB);
    dict[@"monitorCount"] = @(self.monitorCount);
    dict[@"enableHiDPI"] = @(self.enableHiDPI);
    dict[@"enableParallelPort"] = @(self.enableParallelPort);
    dict[@"enableSoundCard"] = @(self.enableSoundCard);
    dict[@"soundCardModel"] = self.soundCardModel ?: @"hda";
    dict[@"cpuSockets"] = @(self.cpuSockets);
    dict[@"cpuCoresPerSocket"] = @(self.cpuCoresPerSocket);
    dict[@"enableSharedClipboard"] = @(self.enableSharedClipboard);
    dict[@"enableDragDrop"] = @(self.enableDragDrop);
    dict[@"enableTimeSync"] = @(self.enableTimeSync);
    dict[@"performanceProfile"] = self.performanceProfile ?: @"balanced";
    dict[@"snapshots"] = self.snapshots ?: @[];
    dict[@"enableAutoSnapshot"] = @(self.enableAutoSnapshot);
    dict[@"autoSnapshotInterval"] = @(self.autoSnapshotInterval);
    dict[@"isEncrypted"] = @(self.isEncrypted);
    dict[@"encryptionKeyHash"] = self.encryptionKeyHash ?: @"";
    dict[@"isFavorite"] = @(self.isFavorite);
    dict[@"group"] = self.group ?: @"";
    dict[@"portForwards"] = self.portForwards ?: @[];
    dict[@"bridgeInterface"] = self.bridgeInterface ?: @"";
    dict[@"hostOnlySubnet"] = self.hostOnlySubnet ?: @"192.168.56.0/24";
    dict[@"enableDHCP"] = @(self.enableDHCP);
    dict[@"dhcpRangeStart"] = self.dhcpRangeStart ?: @"192.168.56.100";
    dict[@"dhcpRangeEnd"] = self.dhcpRangeEnd ?: @"192.168.56.254";
    dict[@"enableIPv6"] = @(self.enableIPv6);
    dict[@"autoStart"] = @(self.autoStart);
    dict[@"tags"] = self.tags ?: @[];
    return dict;
}

- (void)loadFromDictionary:(NSDictionary *)dict {
    self.name = dict[@"name"] ?: @"";
    self.vmIdentifier = dict[@"identifier"] ?: [[NSUUID UUID] UUIDString];
    self.architecture = [dict[@"architecture"] integerValue];
    self.osType = [dict[@"osType"] integerValue];
    self.machineType = dict[@"machineType"] ?: @"default";
    self.cpuModel = dict[@"cpuModel"] ?: @"default";
    self.cpuCores = [dict[@"cpuCores"] integerValue];
    self.memoryValue = [dict[@"memoryValue"] integerValue];
    self.memoryUnit = dict[@"memoryUnit"] ?: @"MB";
    if (self.memoryValue == 0 && dict[@"memoryMB"]) {
        self.memoryValue = [dict[@"memoryMB"] integerValue];
        self.memoryUnit = @"MB";
    }
    self.diskImagePath = dict[@"diskImagePath"] ?: @"";
    self.diskSizeValue = [dict[@"diskSizeValue"] integerValue];
    self.diskSizeUnit = dict[@"diskSizeUnit"] ?: @"GB";
    if (self.diskSizeValue == 0 && dict[@"diskSizeGB"]) {
        self.diskSizeValue = [dict[@"diskSizeGB"] integerValue];
        self.diskSizeUnit = @"GB";
    }
    self.cdromImagePath = dict[@"cdromImagePath"];
    self.bootISOPath = dict[@"bootISOPath"];
    self.floppyAPath = dict[@"floppyAPath"];
    self.floppyBPath = dict[@"floppyBPath"];
    self.sharedFolders = dict[@"sharedFolders"] ?: @[];
    self.romFilePath = dict[@"romFilePath"];
    self.classicMacModel = dict[@"classicMacModel"];
    self.networkMode = dict[@"networkMode"] ?: @"user";
    self.displayType = dict[@"displayType"] ?: @"cocoa";
    self.enableAudio = [dict[@"enableAudio"] boolValue];
    self.enableUSB = [dict[@"enableUSB"] boolValue];
    self.enableAcceleration = [dict[@"enableAcceleration"] boolValue];
    self.biosPath = dict[@"biosPath"] ?: @"";
    self.additionalArgs = dict[@"additionalArgs"] ?: @[];
    self.vncPort = [dict[@"vncPort"] integerValue];
    self.notes = dict[@"notes"] ?: @"";
    NSTimeInterval created = [dict[@"createdAt"] doubleValue];
    self.createdAt = created > 0 ? [NSDate dateWithTimeIntervalSince1970:created] : [NSDate date];
    NSTimeInterval lastUsed = [dict[@"lastUsedAt"] doubleValue];
    self.lastUsedAt = lastUsed > 0 ? [NSDate dateWithTimeIntervalSince1970:lastUsed] : [NSDate date];
    // Enhanced
    self.diskController = dict[@"diskController"] ?: @"VirtIO";
    self.usbVersion = dict[@"usbVersion"] ?: @"3.0";
    self.enableTPM = [dict[@"enableTPM"] boolValue];
    self.enable3DAcceleration = [dict[@"enable3DAcceleration"] boolValue];
    self.vramSizeMB = [dict[@"vramSizeMB"] integerValue];
    if (self.vramSizeMB == 0) self.vramSizeMB = 128;
    self.monitorCount = [dict[@"monitorCount"] integerValue];
    if (self.monitorCount == 0) self.monitorCount = 1;
    self.enableHiDPI = [dict[@"enableHiDPI"] boolValue];
    self.enableParallelPort = [dict[@"enableParallelPort"] boolValue];
    self.enableSoundCard = [dict[@"enableSoundCard"] boolValue];
    self.soundCardModel = dict[@"soundCardModel"] ?: @"hda";
    self.cpuSockets = [dict[@"cpuSockets"] integerValue];
    if (self.cpuSockets == 0) self.cpuSockets = 1;
    self.cpuCoresPerSocket = [dict[@"cpuCoresPerSocket"] integerValue];
    if (self.cpuCoresPerSocket == 0) self.cpuCoresPerSocket = self.cpuCores;
    self.enableSharedClipboard = [dict[@"enableSharedClipboard"] boolValue];
    self.enableDragDrop = [dict[@"enableDragDrop"] boolValue];
    self.enableTimeSync = [dict[@"enableTimeSync"] boolValue];
    self.performanceProfile = dict[@"performanceProfile"] ?: @"balanced";
    self.snapshots = dict[@"snapshots"] ?: @[];
    self.enableAutoSnapshot = [dict[@"enableAutoSnapshot"] boolValue];
    self.autoSnapshotInterval = [dict[@"autoSnapshotInterval"] integerValue];
    if (self.autoSnapshotInterval == 0) self.autoSnapshotInterval = 60;
    self.isEncrypted = [dict[@"isEncrypted"] boolValue];
    self.encryptionKeyHash = dict[@"encryptionKeyHash"];
    self.isFavorite = [dict[@"isFavorite"] boolValue];
    self.group = dict[@"group"] ?: @"";
    self.portForwards = dict[@"portForwards"] ?: @[];
    self.bridgeInterface = dict[@"bridgeInterface"] ?: @"";
    self.hostOnlySubnet = dict[@"hostOnlySubnet"] ?: @"192.168.56.0/24";
    self.enableDHCP = [dict[@"enableDHCP"] boolValue];
    self.dhcpRangeStart = dict[@"dhcpRangeStart"] ?: @"192.168.56.100";
    self.dhcpRangeEnd = dict[@"dhcpRangeEnd"] ?: @"192.168.56.254";
    self.enableIPv6 = [dict[@"enableIPv6"] boolValue];
    self.autoStart = [dict[@"autoStart"] boolValue];
    self.tags = dict[@"tags"] ?: @[];
}

- (BOOL)saveToBundle {
    if (!self.vmBundlePath) return NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:self.vmBundlePath]) {
        [fm createDirectoryAtPath:self.vmBundlePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *configPath = [self.vmBundlePath stringByAppendingPathComponent:kVMConfigFileName];
    NSDictionary *dict = [self toDictionary];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    return [data writeToFile:configPath atomically:YES];
}

- (BOOL)loadFromBundle:(NSString *)bundlePath {
    self.vmBundlePath = bundlePath;
    NSString *configPath = [bundlePath stringByAppendingPathComponent:kVMConfigFileName];
    NSData *data = [NSData dataWithContentsOfFile:configPath];
    if (!data) return NO;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!dict) return NO;
    [self loadFromDictionary:dict];
    return YES;
}

#pragma mark - QEMU

- (NSString *)qemuBinaryPath {
    NSString *binaryName = [VMNexusVirtualMachine qemuBinaryNameForArchitecture:self.architecture];
    NSArray *searchPaths = @[@"/opt/homebrew/bin", @"/usr/local/bin", @"/usr/bin"];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in searchPaths) {
        NSString *fullPath = [path stringByAppendingPathComponent:binaryName];
        if ([fm fileExistsAtPath:fullPath]) return fullPath;
    }
    return [NSString stringWithFormat:@"/opt/homebrew/bin/%@", binaryName];
}

- (NSArray<NSString *> *)buildQEMUArguments {
    NSMutableArray *args = [NSMutableArray array];
    BOOL isAppleSiliconHost = [self isAppleSiliconHost];
    BOOL isAArch64 = (self.architecture == VMNexusArchAArch64);
    BOOL isARM32 = (self.architecture == VMNexusArchARM);
    [args addObject:@"-name"];
    [args addObject:self.name];
    [args addObject:@"-m"];
    // Convert memory to MB for QEMU
    NSInteger memMB = [VMNexusVirtualMachine convertValue:self.memoryValue fromUnit:self.memoryUnit ?: @"MB" toUnit:@"MB"];
    if (memMB < 1) memMB = 1;
    [args addObject:[NSString stringWithFormat:@"%ld", (long)memMB]];
    [args addObject:@"-smp"];
    NSInteger totalCores = self.cpuSockets > 0 ? self.cpuSockets * self.cpuCoresPerSocket : self.cpuCores;
    NSInteger sockets = self.cpuSockets > 0 ? self.cpuSockets : 1;
    NSInteger coresPerSock = self.cpuCoresPerSocket > 0 ? self.cpuCoresPerSocket : totalCores / sockets;
    [args addObject:[NSString stringWithFormat:@"cores=%ld,sockets=%ld,threads=1", (long)coresPerSock, (long)sockets]];
    // Machine type - Apple Silicon AArch64 needs special handling
    if (isAArch64 && isAppleSiliconHost) {
        NSString *machine = @"virt";
        if (self.machineType.length > 0 && ![self.machineType isEqualToString:@"default"]) {
            machine = self.machineType;
        }
        [args addObject:@"-M"];
        [args addObject:[NSString stringWithFormat:@"%@,highmem=on", machine]];
    } else if (self.machineType && ![self.machineType isEqualToString:@"default"]) {
        [args addObject:@"-M"];
        [args addObject:self.machineType];
    }
    // CPU - use host passthrough on Apple Silicon for AArch64
    if (isAArch64 && isAppleSiliconHost && self.enableAcceleration) {
        [args addObject:@"-cpu"];
        [args addObject:@"host"];
    } else if (self.cpuModel && ![self.cpuModel isEqualToString:@"default"]) {
        [args addObject:@"-cpu"];
        [args addObject:self.cpuModel];
    }
    // Acceleration
    if (self.enableAcceleration) {
        if (isAppleSiliconHost && (isAArch64 || self.architecture == VMNexusArchX86_64)) {
            [args addObject:@"-accel"];
            [args addObject:@"hvf"];
        }
        [args addObject:@"-accel"];
        [args addObject:@"tcg"];
    }
    // EFI firmware for AArch64 (required to boot most OSes)
    if (isAArch64) {
        NSString *efiFirmware = [self findAArch64Firmware];
        if (efiFirmware) {
            [args addObject:@"-bios"];
            [args addObject:efiFirmware];
        }
    }
    // Custom BIOS override
    if (self.biosPath.length > 0) {
        [args addObject:@"-bios"];
        [args addObject:self.biosPath];
    }
    // Disk with controller type
    if (self.diskImagePath.length > 0) {
        NSString *diskPath = self.diskImagePath;
        if (![diskPath hasPrefix:@"/"]) {
            diskPath = [self.vmBundlePath stringByAppendingPathComponent:diskPath];
        }
        NSString *controller = self.diskController ?: @"VirtIO";
        if ([controller isEqualToString:@"NVMe"]) {
            [args addObject:@"-drive"];
            [args addObject:[NSString stringWithFormat:@"file=%@,format=qcow2,if=none,id=hd0", diskPath]];
            [args addObject:@"-device"];
            [args addObject:@"nvme,drive=hd0,serial=AIRVM001"];
        } else if ([controller isEqualToString:@"SCSI"]) {
            [args addObject:@"-device"];
            [args addObject:@"lsi53c895a,id=scsi0"];
            [args addObject:@"-drive"];
            [args addObject:[NSString stringWithFormat:@"file=%@,format=qcow2,if=none,id=hd0", diskPath]];
            [args addObject:@"-device"];
            [args addObject:@"scsi-hd,drive=hd0,bus=scsi0.0"];
        } else if ([controller isEqualToString:@"SATA"]) {
            [args addObject:@"-device"];
            [args addObject:@"ahci,id=ahci0"];
            [args addObject:@"-drive"];
            [args addObject:[NSString stringWithFormat:@"file=%@,format=qcow2,if=none,id=hd0", diskPath]];
            [args addObject:@"-device"];
            [args addObject:@"ide-hd,drive=hd0,bus=ahci0.0"];
        } else {
            // VirtIO (default)
            [args addObject:@"-drive"];
            [args addObject:[NSString stringWithFormat:@"file=%@,format=qcow2,if=none,id=hd0", diskPath]];
            [args addObject:@"-device"];
            [args addObject:@"virtio-blk-pci,drive=hd0"];
        }
    }
    if (self.cdromImagePath.length > 0) {
        [args addObject:@"-cdrom"];
        [args addObject:self.cdromImagePath];
    }
    if (self.bootISOPath.length > 0) {
        [args addObject:@"-boot"];
        [args addObject:@"d"];
        if (![args containsObject:@"-cdrom"]) {
            [args addObject:@"-cdrom"];
        }
        [args addObject:self.bootISOPath];
    }
    // Network
    [args addObject:@"-netdev"];
    [args addObject:[NSString stringWithFormat:@"user,id=net0,hostfwd=tcp::%ld-:22", (long)(2200 + arc4random_uniform(1000))]];
    [args addObject:@"-device"];
    if (self.architecture == VMNexusArchX86_64 || self.architecture == VMNexusArchX86) {
        [args addObject:@"e1000,netdev=net0"];
    } else {
        [args addObject:@"virtio-net-pci,netdev=net0"];
    }
    // Display - 3D acceleration + VRAM + multi-monitor
    [args addObject:@"-display"];
    [args addObject:self.displayType.length > 0 ? self.displayType : @"cocoa"];
    NSString *vgaDevice = @"virtio-gpu-pci";
    if (self.enable3DAcceleration) {
        vgaDevice = [NSString stringWithFormat:@"virtio-gpu-gl-pci"];
    } else if (self.architecture == VMNexusArchX86 || self.architecture == VMNexusArchX86_64) {
        vgaDevice = @"VGA";  // std VGA for x86
    }
    NSInteger vramKB = self.vramSizeMB > 0 ? self.vramSizeMB * 1024 : 131072;
    [args addObject:@"-device"];
    [args addObject:[NSString stringWithFormat:@"%@,vgamem_kb=%ld", vgaDevice, (long)vramKB]];
    if (self.enableHiDPI && self.monitorCount > 1) {
        // Add extra display heads
        for (NSInteger i = 1; i < self.monitorCount; i++) {
            [args addObject:@"-device"];
            [args addObject:@"virtio-gpu-pci"];
        }
    }
    if (self.vncPort > 0) {
        [args addObject:@"-vnc"];
        [args addObject:[NSString stringWithFormat:@":%ld", (long)(self.vncPort - 5900)]];
    }
    // Audio with sound card model selection
    if (self.enableAudio && self.enableSoundCard) {
        [args addObject:@"-audiodev"];
        [args addObject:@"coreaudio,id=audio0"];
        NSString *sndModel = self.soundCardModel ?: @"hda";
        if ([sndModel isEqualToString:@"hda"]) {
            [args addObject:@"-device"];
            [args addObject:@"intel-hda"];
            [args addObject:@"-device"];
            [args addObject:@"hda-duplex,audiodev=audio0"];
        } else if ([sndModel isEqualToString:@"ac97"]) {
            [args addObject:@"-device"];
            [args addObject:@"AC97,audiodev=audio0"];
        } else if ([sndModel isEqualToString:@"es1370"]) {
            [args addObject:@"-device"];
            [args addObject:@"ES1370,audiodev=audio0"];
        } else if ([sndModel isEqualToString:@"sb16"]) {
            [args addObject:@"-device"];
            [args addObject:@"sb16,audiodev=audio0"];
        }
    }
    // USB with version selection
    if (self.enableUSB) {
        NSString *usbVer = self.usbVersion ?: @"3.0";
        if ([usbVer isEqualToString:@"3.1"] || [usbVer isEqualToString:@"3.0"]) {
            [args addObject:@"-device"];
            [args addObject:@"qemu-xhci,id=usb0"];
        } else {
            // USB 2.0
            [args addObject:@"-device"];
            [args addObject:@"ich9-usb-ehci1,id=usb0"];
            [args addObject:@"-device"];
            [args addObject:@"ich9-usb-uhci1,masterbus=usb0.0,firstport=0,multifunction=on"];
        }
        [args addObject:@"-device"];
        [args addObject:@"usb-kbd"];
        [args addObject:@"-device"];
        [args addObject:@"usb-tablet"];
    }
    // Virtual TPM
    if (self.enableTPM) {
        NSString *tpmDir = [self.vmBundlePath stringByAppendingPathComponent:@"tpmstate"];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:tpmDir]) {
            [fm createDirectoryAtPath:tpmDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSString *tpmSock = [tpmDir stringByAppendingPathComponent:@"swtpm-sock"];
        [args addObject:@"-chardev"];
        [args addObject:[NSString stringWithFormat:@"socket,id=chrtpm,path=%@", tpmSock]];
        [args addObject:@"-tpmdev"];
        [args addObject:@"emulator,id=tpm0,chardev=chrtpm"];
        [args addObject:@"-device"];
        [args addObject:@"tpm-tis,tpmdev=tpm0"];
    }
    // Parallel port
    if (self.enableParallelPort) {
        [args addObject:@"-parallel"];
        [args addObject:@"stdio"];
    }
    // Floppy disks
    if (self.floppyAPath.length > 0) {
        [args addObject:@"-fda"];
        [args addObject:self.floppyAPath];
    }
    if (self.floppyBPath.length > 0) {
        [args addObject:@"-fdb"];
        [args addObject:self.floppyBPath];
    }
    // Shared folders via virtio-9p
    for (NSInteger i = 0; i < (NSInteger)self.sharedFolders.count; i++) {
        NSDictionary *folder = self.sharedFolders[i];
        NSString *name = folder[@"name"] ?: [NSString stringWithFormat:@"share%ld", (long)i];
        NSString *path = folder[@"hostPath"];
        if (path.length == 0) continue;
        NSString *devId = [NSString stringWithFormat:@"fs%ld", (long)i];
        NSString *mountTag = [NSString stringWithFormat:@"hostshare%ld", (long)i];
        [args addObject:@"-fsdev"];
        [args addObject:[NSString stringWithFormat:@"local,id=%@,path=%@,security_model=mapped-xattr", devId, path]];
        [args addObject:@"-device"];
        [args addObject:[NSString stringWithFormat:@"virtio-9p-pci,fsdev=%@,mount_tag=%@", devId, mountTag]];
    }
    // Shared clipboard & drag-drop via qemu-vdagent
    if (self.enableSharedClipboard || self.enableDragDrop) {
        [args addObject:@"-device"];
        [args addObject:@"virtio-serial-pci,id=virtio-serial0"];
        [args addObject:@"-chardev"];
        [args addObject:@"spicevmc,id=vdagent,name=vdagent"];
        [args addObject:@"-device"];
        [args addObject:@"virtserialport,chardev=vdagent,name=com.redhat.spice.0"];
    }
    // Guest time sync
    if (self.enableTimeSync) {
        [args addObject:@"-rtc"];
        [args addObject:@"base=localtime,clock=host"];
    }
    [args addObject:@"-monitor"];
    [args addObject:@"stdio"];
    for (NSString *arg in self.additionalArgs) {
        [args addObject:arg];
    }
    return args;
}

- (BOOL)isAppleSiliconHost {
#if defined(__aarch64__) || defined(__arm64__)
    return YES;
#else
    return NO;
#endif
}

- (NSString *)findAArch64Firmware {
    NSArray *firmwarePaths = @[
        @"/opt/homebrew/share/qemu/edk2-aarch64-code.fd",
        @"/opt/homebrew/Cellar/qemu/*/share/qemu/edk2-aarch64-code.fd",
        @"/usr/local/share/qemu/edk2-aarch64-code.fd",
        @"/usr/share/qemu-efi-aarch64/QEMU_EFI.fd",
        @"/usr/share/AAVMF/AAVMF_CODE.fd",
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in firmwarePaths) {
        if ([path containsString:@"*"]) {
            NSString *dir = [path stringByDeletingLastPathComponent];
            NSString *pattern = [path lastPathComponent];
            NSArray *dirs = [fm contentsOfDirectoryAtPath:[dir stringByDeletingLastPathComponent] error:nil];
            for (NSString *d in dirs) {
                NSString *candidate = [[[dir stringByDeletingLastPathComponent] stringByAppendingPathComponent:d] stringByAppendingPathComponent:pattern];
                if ([fm fileExistsAtPath:candidate]) return candidate;
            }
        } else {
            if ([fm fileExistsAtPath:path]) return path;
        }
    }
    return nil;
}

#pragma mark - Unit Conversion

+ (NSArray<NSString *> *)supportedUnits {
    return @[@"KB", @"MB", @"GB", @"TB"];
}

+ (NSArray<NSString *> *)physicalOpticalDrives {
    NSMutableArray *drives = [NSMutableArray array];
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/system_profiler"];
    task.arguments = @[@"SPDiscBurningDataType", @"-xml"];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = [NSPipe pipe];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) { return @[]; }
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    if (data.length > 0) {
        // If we got output, there are optical drives
        // Use diskutil to find the actual device paths
        NSTask *duTask = [[NSTask alloc] init];
        duTask.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/diskutil"];
        duTask.arguments = @[@"list"];
        NSPipe *duPipe = [NSPipe pipe];
        duTask.standardOutput = duPipe;
        duTask.standardError = [NSPipe pipe];
        @try {
            [duTask launch];
            [duTask waitUntilExit];
        } @catch (NSException *e) { return drives; }
        NSString *duOut = [[NSString alloc] initWithData:[[duPipe fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        NSArray *lines = [duOut componentsSeparatedByString:@"\n"];
        for (NSString *line in lines) {
            if ([line containsString:@"/dev/disk"] && [line containsString:@"external"]) {
                NSScanner *scanner = [NSScanner scannerWithString:line];
                NSString *dev = nil;
                [scanner scanString:@"/dev/" intoString:nil];
                if ([scanner scanUpToString:@" " intoString:&dev]) {
                    [drives addObject:[NSString stringWithFormat:@"/dev/%@", dev]];
                }
            }
        }
    }
    return drives;
}

+ (NSArray<NSString *> *)physicalFloppyDrives {
    // macOS doesn't natively support floppy drives, but USB floppy drives may appear
    // Check for USB floppy devices (rare on modern macOS)
    NSMutableArray *drives = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    // Check /dev/ for any floppy-like devices
    NSArray *devs = [fm contentsOfDirectoryAtPath:@"/dev" error:nil];
    for (NSString *dev in devs) {
        if ([dev hasPrefix:@"disk"] && [dev containsString:@"floppy"]) {
            [drives addObject:[NSString stringWithFormat:@"/dev/%@", dev]];
        }
    }
    return drives;
}

+ (NSInteger)convertValue:(NSInteger)value fromUnit:(NSString *)from toUnit:(NSString *)to {
    NSDictionary *multipliers = @{@"KB": @(1024LL), @"MB": @(1024LL*1024), @"GB": @(1024LL*1024*1024), @"TB": @(1024LL*1024*1024*1024)};
    NSNumber *fromMul = multipliers[from] ?: multipliers[@"MB"];
    NSNumber *toMul = multipliers[to] ?: multipliers[@"MB"];
    long long bytes = (long long)value * [fromMul longLongValue];
    return (NSInteger)(bytes / [toMul longLongValue]);
}

- (NSInteger)memoryInBytes {
    return [VMNexusVirtualMachine convertValue:self.memoryValue fromUnit:self.memoryUnit ?: @"MB" toUnit:@"KB"] * 1024LL;
}

- (NSString *)diskSizeForQEMU {
    // QEMU qemu-img create takes size as e.g. "20G", "512M", "1T"
    NSString *unit = self.diskSizeUnit ?: @"GB";
    if ([unit isEqualToString:@"none"]) return nil; // no disk
    NSString *suffix = @"G";
    if ([unit isEqualToString:@"KB"]) suffix = @"K";
    else if ([unit isEqualToString:@"MB"]) suffix = @"M";
    else if ([unit isEqualToString:@"GB"]) suffix = @"G";
    else if ([unit isEqualToString:@"TB"]) suffix = @"T";
    return [NSString stringWithFormat:@"%ld%@", (long)self.diskSizeValue, suffix];
}

#pragma mark - Disk Usage

- (NSString *)diskImagePathResolved {
    if (!self.diskImagePath || self.diskImagePath.length == 0) return nil;
    if ([self.diskImagePath hasPrefix:@"/"]) return self.diskImagePath;
    // Relative path - resolve against VM bundle
    return [self.vmBundlePath stringByAppendingPathComponent:self.diskImagePath];
}

- (NSInteger)diskUsedBytes {
    // Find the actual disk image file and get its size
    NSString *diskPath = [self diskImagePathResolved];
    if (!diskPath || ![[NSFileManager defaultManager] fileExistsAtPath:diskPath]) {
        return 0;
    }
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:diskPath error:nil];
    return [attrs[NSFileSize] integerValue];
}

- (NSInteger)diskTotalBytes {
    // Convert configured disk size to bytes
    if ([self.diskSizeUnit isEqualToString:@"none"]) return 0;
    return [VMNexusVirtualMachine convertValue:self.diskSizeValue fromUnit:self.diskSizeUnit ?: @"GB" toUnit:@"KB"] * 1024LL;
}

- (CGFloat)diskUsagePercent {
    NSInteger total = [self diskTotalBytes];
    if (total <= 0) return 0;
    NSInteger used = [self diskUsedBytes];
    return MIN(1.0, (CGFloat)used / (CGFloat)total);
}

#pragma mark - Display Names

- (NSString *)architectureDisplayName {
    return [VMNexusVirtualMachine displayNameForArchitecture:self.architecture];
}

- (NSString *)statusDisplayName {
    switch (self.status) {
        case VMNexusStatusStopped: return AMLocalizedString(@"status.stopped");
        case VMNexusStatusStarting: return AMLocalizedString(@"status.starting");
        case VMNexusStatusRunning: return AMLocalizedString(@"status.running");
        case VMNexusStatusPaused: return AMLocalizedString(@"status.paused");
        case VMNexusStatusStopping: return AMLocalizedString(@"status.stopping");
        case VMNexusStatusError: return AMLocalizedString(@"status.error");
    }
    return @"Unknown";
}

- (NSString *)osDisplayName {
    switch (self.osType) {
        case VMNexusOSWindowsXP: return @"Windows XP";
        case VMNexusOSWindows7: return @"Windows 7";
        case VMNexusOSWindows8: return @"Windows 8";
        case VMNexusOSWindows10: return @"Windows 10";
        case VMNexusOSWindows11: return @"Windows 11";
        case VMNexusOSWindowsServer: return @"Windows Server";
        case VMNexusOSUbuntu: return @"Ubuntu";
        case VMNexusOSDebian: return @"Debian";
        case VMNexusOSFedora: return @"Fedora";
        case VMNexusOSCentOS: return @"CentOS";
        case VMNexusOSArch: return @"Arch Linux";
        case VMNexusOSLinux: return @"Linux";
        case VMNexusOSFreeBSD: return @"FreeBSD";
        case VMNexusOSOpenBSD: return @"OpenBSD";
        case VMNexusOSMacOSX: return @"macOS";
        case VMNexusOSClassicMac: return @"Classic Mac OS";
        case VMNexusOSAndroid: return @"Android";
        case VMNexusOSDOS: return @"DOS";
        case VMNexusOSReactOS: return @"ReactOS";
        case VMNexusOSSolaris: return @"Solaris";
        case VMNexusOSHaiku: return @"Haiku";
        case VMNexusOSCommodore: return @"Commodore";
        case VMNexusOSMSX: return @"MSX";
        default: return @"Other";
    }
}

- (NSImage *)osIcon {
    NSString *iconName;
    switch (self.osType) {
        case VMNexusOSWindowsXP:
        case VMNexusOSWindows7:
        case VMNexusOSWindows8:
        case VMNexusOSWindows10:
        case VMNexusOSWindows11:
        case VMNexusOSWindowsServer:
            iconName = @"windows"; break;
        case VMNexusOSUbuntu: iconName = @"ubuntu"; break;
        case VMNexusOSDebian: iconName = @"debian"; break;
        case VMNexusOSFedora: iconName = @"fedora"; break;
        case VMNexusOSCentOS: iconName = @"centos"; break;
        case VMNexusOSArch: iconName = @"arch"; break;
        case VMNexusOSLinux: iconName = @"linux"; break;
        case VMNexusOSFreeBSD: iconName = @"freebsd"; break;
        case VMNexusOSOpenBSD: iconName = @"openbsd"; break;
        case VMNexusOSMacOSX: iconName = @"apple"; break;
        case VMNexusOSClassicMac: iconName = @"apple"; break;
        case VMNexusOSAndroid: iconName = @"android"; break;
        case VMNexusOSDOS: iconName = @"dos"; break;
        case VMNexusOSReactOS: iconName = @"reactos"; break;
        case VMNexusOSSolaris: iconName = @"solaris"; break;
        case VMNexusOSHaiku: iconName = @"haiku"; break;
        case VMNexusOSCommodore: iconName = @"commodore"; break;
        case VMNexusOSMSX:
        default: iconName = @"terminal"; break;
    }
    NSString *path = [[NSBundle mainBundle] pathForResource:iconName ofType:@"png" inDirectory:@"OSIcons"];
    if (path) {
        NSImage *img = [[NSImage alloc] initWithContentsOfFile:path];
        if (img) return img;
    }
    // Fallback to SF Symbol
    return [NSImage imageWithSystemSymbolName:@"desktopcomputer" accessibilityDescription:nil];
}

+ (NSArray<NSString *> *)allOSTypeNames {
    return @[
        @"Other",
        @"Windows XP",
        @"Windows 7",
        @"Windows 8",
        @"Windows 10",
        @"Windows 11",
        @"Windows Server",
        @"Ubuntu",
        @"Debian",
        @"Fedora",
        @"CentOS",
        @"Arch Linux",
        @"Linux (Generic)",
        @"FreeBSD",
        @"OpenBSD",
        @"macOS",
        @"Classic Mac OS",
        @"Android",
        @"DOS",
        @"ReactOS",
        @"Solaris",
        @"Haiku",
        @"Commodore",
        @"MSX",
    ];
}

+ (NSDictionary *)presetConfigForOSType:(VMNexusOSType)osType {
    switch (osType) {
        case VMNexusOSWindowsXP:
            return @{@"arch": @(VMNexusArchX86), @"machine": @"pc-i440fx", @"cpu": @"pentium3", @"cores": @(1), @"memMB": @(512), @"diskGB": @(20), @"vram": @(64)};
        case VMNexusOSWindows7:
            return @{@"arch": @(VMNexusArchX86_64), @"machine": @"pc-q35", @"cpu": @"core2duo", @"cores": @(2), @"memMB": @(2048), @"diskGB": @(40), @"vram": @(256)};
        case VMNexusOSWindows10:
        case VMNexusOSWindows11:
            return @{@"arch": @(VMNexusArchX86_64), @"machine": @"pc-q35", @"cpu": @"host", @"cores": @(4), @"memMB": @(4096), @"diskGB": @(64), @"vram": @(512), @"tpm": @(YES)};
        case VMNexusOSUbuntu:
        case VMNexusOSDebian:
        case VMNexusOSFedora:
        case VMNexusOSCentOS:
        case VMNexusOSArch:
            return @{@"arch": @(VMNexusArchX86_64), @"machine": @"pc-q35", @"cpu": @"host", @"cores": @(2), @"memMB": @(2048), @"diskGB": @(30), @"vram": @(256)};
        case VMNexusOSLinux:
            return @{@"arch": @(VMNexusArchX86_64), @"machine": @"pc-q35", @"cpu": @"host", @"cores": @(2), @"memMB": @(1024), @"diskGB": @(20), @"vram": @(128)};
        case VMNexusOSFreeBSD:
        case VMNexusOSOpenBSD:
            return @{@"arch": @(VMNexusArchX86_64), @"machine": @"pc-q35", @"cpu": @"host", @"cores": @(1), @"memMB": @(1024), @"diskGB": @(20), @"vram": @(64)};
        case VMNexusOSMacOSX:
            return @{@"arch": @(VMNexusArchAArch64), @"machine": @"virt", @"cpu": @"host", @"cores": @(4), @"memMB": @(8192), @"diskGB": @(64), @"vram": @(512)};
        case VMNexusOSClassicMac:
            return @{@"arch": @(VMNexusArchPPC), @"machine": @"mac99", @"cpu": @"default", @"cores": @(1), @"memMB": @(256), @"diskGB": @(2), @"vram": @(16)};
        case VMNexusOSAndroid:
            return @{@"arch": @(VMNexusArchX86_64), @"machine": @"pc-q35", @"cpu": @"host", @"cores": @(2), @"memMB": @(2048), @"diskGB": @(8), @"vram": @(256)};
        case VMNexusOSDOS:
            return @{@"arch": @(VMNexusArchX86), @"machine": @"pc-i440fx", @"cpu": @"pentium", @"cores": @(1), @"memMB": @(64), @"diskGB": @(2), @"vram": @(4)};
        case VMNexusOSReactOS:
            return @{@"arch": @(VMNexusArchX86), @"machine": @"pc-i440fx", @"cpu": @"pentium3", @"cores": @(1), @"memMB": @(512), @"diskGB": @(10), @"vram": @(64)};
        default:
            return @{@"arch": @(VMNexusArchX86_64), @"machine": @"pc-q35", @"cpu": @"host", @"cores": @(2), @"memMB": @(2048), @"diskGB": @(30), @"vram": @(256)};
    }
}

+ (NSString *)displayNameForArchitecture:(VMNexusArchitecture)arch {
    switch (arch) {
        case VMNexusArchX86: return AMLocalizedString(@"architecture.x86");
        case VMNexusArchX86_64: return AMLocalizedString(@"architecture.x86_64");
        case VMNexusArchARM: return AMLocalizedString(@"architecture.arm");
        case VMNexusArchAArch64: return AMLocalizedString(@"architecture.aarch64");
        case VMNexusArchMIPS: return AMLocalizedString(@"architecture.mips");
        case VMNexusArchMIPS64: return AMLocalizedString(@"architecture.mips64");
        case VMNexusArchMIPSEL: return AMLocalizedString(@"architecture.mipsel");
        case VMNexusArchMIPS64EL: return AMLocalizedString(@"architecture.mips64el");
        case VMNexusArchPPC: return AMLocalizedString(@"architecture.ppc");
        case VMNexusArchPPC64: return AMLocalizedString(@"architecture.ppc64");
        case VMNexusArchRISCV32: return AMLocalizedString(@"architecture.riscv32");
        case VMNexusArchRISCV64: return AMLocalizedString(@"architecture.riscv64");
        case VMNexusArchS390x: return AMLocalizedString(@"architecture.s390x");
        case VMNexusArchSPARC: return AMLocalizedString(@"architecture.sparc");
        case VMNexusArchSPARC64: return AMLocalizedString(@"architecture.sparc64");
        case VMNexusArchM68k: return AMLocalizedString(@"architecture.m68k");
        case VMNexusArchAlpha: return AMLocalizedString(@"architecture.alpha");
        case VMNexusArchHPPA: return AMLocalizedString(@"architecture.hppa");
        case VMNexusArchSH4: return AMLocalizedString(@"architecture.sh4");
        case VMNexusArchSH4EB: return AMLocalizedString(@"architecture.sh4eb");
        case VMNexusArchMicroBlaze: return AMLocalizedString(@"architecture.microblaze");
        case VMNexusArchMicroBlazeEL: return AMLocalizedString(@"architecture.microblazeel");
        case VMNexusArchOR1K: return AMLocalizedString(@"architecture.or1k");
        case VMNexusArchLoongArch64: return AMLocalizedString(@"architecture.loongarch64");
        case VMNexusArchXtensa: return AMLocalizedString(@"architecture.xtensa");
        case VMNexusArchXtensaEB: return AMLocalizedString(@"architecture.xtensaeb");
        case VMNexusArchTricore: return AMLocalizedString(@"architecture.tricore");
        case VMNexusArchAVR: return AMLocalizedString(@"architecture.avr");
        case VMNexusArchRX: return AMLocalizedString(@"architecture.rx");
        case VMNexusArchClassicMac68k: return AMLocalizedString(@"architecture.classicmac68k");
        case VMNexusArchMac68kII: return AMLocalizedString(@"architecture.mac68kii");
        case VMNexusArchMOS6502: return AMLocalizedString(@"architecture.mos6502");
        case VMNexusArchZ80: return AMLocalizedString(@"architecture.z80");
        case VMNexusArchMultiSystem: return AMLocalizedString(@"architecture.multisystem");
    }
    return AMLocalizedString(@"architecture.unknown");
}

+ (NSString *)qemuBinaryNameForArchitecture:(VMNexusArchitecture)arch {
    switch (arch) {
        case VMNexusArchX86: return @"qemu-system-i386";
        case VMNexusArchX86_64: return @"qemu-system-x86_64";
        case VMNexusArchARM: return @"qemu-system-arm";
        case VMNexusArchAArch64: return @"qemu-system-aarch64";
        case VMNexusArchMIPS: return @"qemu-system-mips";
        case VMNexusArchMIPS64: return @"qemu-system-mips64";
        case VMNexusArchMIPSEL: return @"qemu-system-mipsel";
        case VMNexusArchMIPS64EL: return @"qemu-system-mips64el";
        case VMNexusArchPPC: return @"qemu-system-ppc";
        case VMNexusArchPPC64: return @"qemu-system-ppc64";
        case VMNexusArchRISCV32: return @"qemu-system-riscv32";
        case VMNexusArchRISCV64: return @"qemu-system-riscv64";
        case VMNexusArchS390x: return @"qemu-system-s390x";
        case VMNexusArchSPARC: return @"qemu-system-sparc";
        case VMNexusArchSPARC64: return @"qemu-system-sparc64";
        case VMNexusArchM68k: return @"qemu-system-m68k";
        case VMNexusArchAlpha: return @"qemu-system-alpha";
        case VMNexusArchHPPA: return @"qemu-system-hppa";
        case VMNexusArchSH4: return @"qemu-system-sh4";
        case VMNexusArchSH4EB: return @"qemu-system-sh4eb";
        case VMNexusArchMicroBlaze: return @"qemu-system-microblaze";
        case VMNexusArchMicroBlazeEL: return @"qemu-system-microblazeel";
        case VMNexusArchOR1K: return @"qemu-system-or1k";
        case VMNexusArchLoongArch64: return @"qemu-system-loongarch64";
        case VMNexusArchXtensa: return @"qemu-system-xtensa";
        case VMNexusArchXtensaEB: return @"qemu-system-xtensaeb";
        case VMNexusArchTricore: return @"qemu-system-tricore";
        case VMNexusArchAVR: return @"qemu-system-avr";
        case VMNexusArchRX: return @"qemu-system-rx";
        // Classic / Retro emulators use external engines, no QEMU binary
        case VMNexusArchClassicMac68k: return @"";
        case VMNexusArchMac68kII: return @"";
        case VMNexusArchMOS6502: return @"";
        case VMNexusArchZ80: return @"";
        case VMNexusArchMultiSystem: return @"";
    }
    return @"qemu-system-x86_64";
}

@end
