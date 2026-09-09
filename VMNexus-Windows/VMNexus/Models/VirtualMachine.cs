using System;
using System.Collections.Generic;
using System.Text.Json;
using System.IO;

namespace AirVM.Models
{
    public enum VMStatus
    {
        Stopped, Starting, Running, Paused, Stopping, Error
    }

    public enum VMArchitecture
    {
        X86, X86_64, ARM, AArch64, MIPS, MIPS64,
        MIPSEL, MIPS64EL, PPC, PPC64,
        RISCV32, RISCV64, S390x, SPARC, SPARC64,
        M68k, Alpha, HPPA, SH4, SH4EB,
        MicroBlaze, MicroBlazeEL, OR1K, LoongArch64,
        Xtensa, XtensaEB, Tricore, AVR, RX,
        ClassicMac68k, Mac68kII, MOS6502, Z80, MultiSystem
    }

    public enum AppMode
    {
        Simple, Standard, Advanced
    }

    public class SharedFolder
    {
        public string Name { get; set; } = "";
        public string HostPath { get; set; } = "";
        public bool ReadOnly { get; set; }
    }

    public class PortForwardRule
    {
        public int HostPort { get; set; }
        public string GuestIP { get; set; } = "";
        public int GuestPort { get; set; }
        public string Protocol { get; set; } = "tcp";
    }

    public class SnapshotInfo
    {
        public string Name { get; set; } = "";
        public string Date { get; set; } = "";
        public string Type { get; set; } = "manual";
    }

    public class VirtualMachine
    {
        public string Name { get; set; } = "New Virtual Machine";
        public string Id { get; set; } = Guid.NewGuid().ToString("N").Substring(0, 12);
        public VMArchitecture Architecture { get; set; } = VMArchitecture.X86_64;
        public string MachineType { get; set; } = "default";
        public string CpuModel { get; set; } = "default";
        public int CpuCores { get; set; } = 2;
        public int CpuSockets { get; set; } = 1;
        public int CpuCoresPerSocket { get; set; } = 2;
        public int MemoryValue { get; set; } = 2048;
        public string MemoryUnit { get; set; } = "MB";
        public string DiskImagePath { get; set; } = "";
        public int DiskSizeValue { get; set; } = 20;
        public string DiskSizeUnit { get; set; } = "GB";
        public string DiskController { get; set; } = "VirtIO"; // SCSI, SATA, NVMe, VirtIO
        public string CdromImagePath { get; set; } = "";
        public string BootISOPath { get; set; } = "";
        public string FloppyAPath { get; set; } = "";
        public string FloppyBPath { get; set; } = "";
        public string RomFilePath { get; set; } = "";
        public string ClassicMacModel { get; set; } = "";
        public List<SharedFolder> SharedFolders { get; set; } = new();
        public VMStatus Status { get; set; } = VMStatus.Stopped;
        public string NetworkMode { get; set; } = "user";
        public string DisplayType { get; set; } = "cocoa";
        public int VncPort { get; set; } = 5900;
        public bool EnableAudio { get; set; } = true;
        public string SoundCardModel { get; set; } = "hda"; // hda, ac97, es1370, sb16
        public bool EnableUSB { get; set; } = true;
        public string UsbVersion { get; set; } = "3.0"; // 2.0, 3.0, 3.1
        public bool EnableAcceleration { get; set; } = true;
        public bool EnableTPM { get; set; }
        public bool Enable3DAcceleration { get; set; }
        public int VramSizeMB { get; set; } = 128;
        public int MonitorCount { get; set; } = 1;
        public bool EnableHiDPI { get; set; } = true;
        public bool EnableParallelPort { get; set; }
        public bool EnableSharedClipboard { get; set; } = true;
        public bool EnableDragDrop { get; set; }
        public bool EnableTimeSync { get; set; } = true;
        public string PerformanceProfile { get; set; } = "balanced";
        public List<SnapshotInfo> Snapshots { get; set; } = new();
        public bool EnableAutoSnapshot { get; set; }
        public int AutoSnapshotInterval { get; set; } = 60;
        public bool IsEncrypted { get; set; }
        public bool IsFavorite { get; set; }
        public string Group { get; set; } = "";
        public List<PortForwardRule> PortForwards { get; set; } = new();
        public string BridgeInterface { get; set; } = "";
        public string HostOnlySubnet { get; set; } = "";
        public bool EnableDHCP { get; set; } = true;
        public string DhcpRangeStart { get; set; } = "";
        public string DhcpRangeEnd { get; set; } = "";
        public bool EnableIPv6 { get; set; }
        public string BiosPath { get; set; } = "";
        public List<string> AdditionalArgs { get; set; } = new();
        public string BundlePath { get; set; } = "";
        public string Notes { get; set; } = "";
        public DateTime CreatedAt { get; set; } = DateTime.Now;
        public DateTime LastUsedAt { get; set; } = DateTime.Now;

        // Extended network features
        public bool EnableModem { get; set; }
        public string ModemSpeed { get; set; } = "56000";
        public bool EnableTerminal { get; set; }
        public bool EnableUnity { get; set; }

        public string ArchitectureDisplayName => Architecture switch
        {
            VMArchitecture.X86_64 => "x86_64",
            VMArchitecture.AArch64 => "ARM 64-bit",
            VMArchitecture.X86 => "x86 (32-bit)",
            VMArchitecture.ARM => "ARM (32-bit)",
            VMArchitecture.ClassicMac68k => "Classic Mac 68K",
            VMArchitecture.Mac68kII => "Mac 68K II",
            VMArchitecture.MOS6502 => "MOS 6502",
            VMArchitecture.Z80 => "Z80",
            VMArchitecture.MultiSystem => "Multi-System",
            _ => Architecture.ToString()
        };

        public string StatusDisplayName => Status switch
        {
            VMStatus.Running => "Running",
            VMStatus.Paused => "Paused",
            VMStatus.Starting => "Starting",
            VMStatus.Stopping => "Stopping",
            VMStatus.Error => "Error",
            _ => "Stopped"
        };

        public System.Windows.Media.Brush StatusColor => Status switch
        {
            VMStatus.Running => new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(64, 191, 96)),
            VMStatus.Paused => new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(245, 166, 35)),
            VMStatus.Starting => new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(59, 130, 246)),
            VMStatus.Error => new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(230, 57, 70)),
            _ => new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(128, 128, 128))
        };

        public void SaveToBundle()
        {
            if (string.IsNullOrEmpty(BundlePath)) return;
            var json = JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true });
            var configPath = Path.Combine(BundlePath, "config.json");
            Directory.CreateDirectory(BundlePath);
            File.WriteAllText(configPath, json);
        }

        public bool LoadFromBundle(string path)
        {
            BundlePath = path;
            var configPath = Path.Combine(path, "config.json");
            if (!File.Exists(configPath)) return false;
            try
            {
                var json = File.ReadAllText(configPath);
                var vm = JsonSerializer.Deserialize<VirtualMachine>(json);
                if (vm != null)
                {
                    Name = vm.Name;
                    Id = vm.Id;
                    Architecture = vm.Architecture;
                    MachineType = vm.MachineType;
                    CpuModel = vm.CpuModel;
                    CpuCores = vm.CpuCores;
                    CpuSockets = vm.CpuSockets;
                    CpuCoresPerSocket = vm.CpuCoresPerSocket;
                    MemoryValue = vm.MemoryValue;
                    MemoryUnit = vm.MemoryUnit;
                    DiskSizeValue = vm.DiskSizeValue;
                    DiskSizeUnit = vm.DiskSizeUnit;
                    DiskController = vm.DiskController ?? "VirtIO";
                    NetworkMode = vm.NetworkMode;
                    DisplayType = vm.DisplayType;
                    VncPort = vm.VncPort;
                    EnableAudio = vm.EnableAudio;
                    SoundCardModel = vm.SoundCardModel ?? "hda";
                    EnableUSB = vm.EnableUSB;
                    UsbVersion = vm.UsbVersion ?? "3.0";
                    EnableAcceleration = vm.EnableAcceleration;
                    EnableTPM = vm.EnableTPM;
                    Enable3DAcceleration = vm.Enable3DAcceleration;
                    VramSizeMB = vm.VramSizeMB;
                    MonitorCount = vm.MonitorCount;
                    EnableHiDPI = vm.EnableHiDPI;
                    EnableParallelPort = vm.EnableParallelPort;
                    EnableSharedClipboard = vm.EnableSharedClipboard;
                    EnableDragDrop = vm.EnableDragDrop;
                    EnableTimeSync = vm.EnableTimeSync;
                    PerformanceProfile = vm.PerformanceProfile ?? "balanced";
                    Snapshots = vm.Snapshots ?? new();
                    EnableAutoSnapshot = vm.EnableAutoSnapshot;
                    AutoSnapshotInterval = vm.AutoSnapshotInterval;
                    IsEncrypted = vm.IsEncrypted;
                    IsFavorite = vm.IsFavorite;
                    Group = vm.Group ?? "";
                    PortForwards = vm.PortForwards ?? new();
                    BridgeInterface = vm.BridgeInterface ?? "";
                    HostOnlySubnet = vm.HostOnlySubnet ?? "";
                    EnableDHCP = vm.EnableDHCP;
                    DhcpRangeStart = vm.DhcpRangeStart ?? "";
                    DhcpRangeEnd = vm.DhcpRangeEnd ?? "";
                    EnableIPv6 = vm.EnableIPv6;
                    BootISOPath = vm.BootISOPath;
                    CdromImagePath = vm.CdromImagePath;
                    FloppyAPath = vm.FloppyAPath;
                    FloppyBPath = vm.FloppyBPath;
                    RomFilePath = vm.RomFilePath;
                    SharedFolders = vm.SharedFolders ?? new();
                    Notes = vm.Notes;
                    CreatedAt = vm.CreatedAt;
                    LastUsedAt = vm.LastUsedAt;
                    EnableModem = vm.EnableModem;
                    ModemSpeed = vm.ModemSpeed;
                    EnableTerminal = vm.EnableTerminal;
                    EnableUnity = vm.EnableUnity;
                    return true;
                }
            }
            catch { }
            return false;
        }

        public string DefaultBundleDirectory()
        {
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            return Path.Combine(appData, "AirVM", "VirtualMachines");
        }
    }
}
