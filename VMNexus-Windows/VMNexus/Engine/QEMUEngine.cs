using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using VMNexus.Models;

namespace VMNexus.Engine
{
    /// <summary>
    /// QEMU process manager — mirrors macOS AirVMQEMUProcess.
    /// Manages launching, monitoring, and controlling a QEMU virtual machine.
    /// </summary>
    public class QEMUEngine : IDisposable
    {
        private readonly VirtualMachine _vm;
        private Process _process;
        private readonly StringBuilder _logOutput = new();
        private CancellationTokenSource _cts;

        public event Action<string> OnOutput;
        public event Action<string> OnError;
        public event Action OnStarted;
        public event Action<int> OnStopped;

        public bool IsRunning { get; private set; }
        public int ProcessId => _process?.Id ?? -1;
        public string LogOutput => _logOutput.ToString();

        public QEMUEngine(VirtualMachine vm)
        {
            _vm = vm ?? throw new ArgumentNullException(nameof(vm));
        }

        // ─── Lifecycle ───

        public void Start()
        {
            if (IsRunning)
                throw new InvalidOperationException("VM is already running");

            var binaryPath = FindQEMUBinary();
            if (string.IsNullOrEmpty(binaryPath) || !File.Exists(binaryPath))
                throw new FileNotFoundException($"QEMU binary not found: {binaryPath}");

            var args = BuildArguments();
            _cts = new CancellationTokenSource();

            _process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = binaryPath,
                    Arguments = string.Join(" ", args),
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    RedirectStandardInput = true,
                    CreateNoWindow = true
                },
                EnableRaisingEvents = true
            };

            _process.OutputDataReceived += (s, e) =>
            {
                if (e.Data != null)
                {
                    _logOutput.AppendLine(e.Data);
                    OnOutput?.Invoke(e.Data);
                }
            };

            _process.ErrorDataReceived += (s, e) =>
            {
                if (e.Data != null)
                {
                    _logOutput.AppendLine(e.Data);
                    OnError?.Invoke(e.Data);
                }
            };

            _process.Exited += (s, e) =>
            {
                IsRunning = false;
                _vm.Status = VMStatus.Stopped;
                var code = _process.ExitCode;
                OnStopped?.Invoke(code);
            };

            try
            {
                _process.Start();
                _process.BeginOutputReadLine();
                _process.BeginErrorReadLine();

                IsRunning = true;
                _vm.Status = VMStatus.Running;
                _vm.LastUsedAt = DateTime.Now;
                _vm.SaveToBundle();
                OnStarted?.Invoke();
            }
            catch (Exception ex)
            {
                _vm.Status = VMStatus.Error;
                throw new InvalidOperationException($"Failed to launch QEMU: {ex.Message}", ex);
            }
        }

        public void Stop()
        {
            if (!IsRunning || _process == null) return;
            _vm.Status = VMStatus.Stopping;
            SendMonitorCommand("system_powerdown");

            // Force stop after 5 seconds if still running
            _ = ThreadPool.QueueUserWorkItem(_ =>
            {
                Thread.Sleep(5000);
                if (IsRunning) ForceStop();
            });
        }

        public void ForceStop()
        {
            if (!IsRunning || _process == null) return;
            try { _process.Kill(entireProcessTree: true); } catch { }
            IsRunning = false;
            _vm.Status = VMStatus.Stopped;
        }

        public void Pause()
        {
            if (!IsRunning) return;
            SendMonitorCommand("stop");
            _vm.Status = VMStatus.Paused;
        }

        public void Resume()
        {
            if (!IsRunning) return;
            SendMonitorCommand("cont");
            _vm.Status = VMStatus.Running;
        }

        public void SendMonitorCommand(string command)
        {
            if (!IsRunning || _process == null) return;
            try
            {
                _process.StandardInput.WriteLine(command);
                _process.StandardInput.Flush();
            }
            catch { /* Process may have exited */ }
        }

        // ─── Argument Builder ───

        private List<string> BuildArguments()
        {
            var args = new List<string>();

            // Machine
            if (_vm.MachineType != "default" && _vm.MachineType != "none")
                args.AddRange(new[] { "-machine", _vm.MachineType });

            // CPU
            if (_vm.CpuModel != "default")
                args.AddRange(new[] { "-cpu", _vm.CpuModel });
            int coresPerSock = _vm.CpuCoresPerSocket > 0 ? _vm.CpuCoresPerSocket : _vm.CpuCores;
            int sockets = _vm.CpuSockets > 0 ? _vm.CpuSockets : 1;
            args.AddRange(new[] { "-smp", $"cores={coresPerSock},sockets={sockets},threads=1" });

            // Memory
            var memStr = $"{_vm.MemoryValue}{_vm.MemoryUnit[0].ToString().ToLower()}";
            args.AddRange(new[] { "-m", memStr });

            // Acceleration
            if (_vm.EnableAcceleration)
                args.AddRange(new[] { "-accel", "kvm:whpx:hvf:tcg" });

            // Display
            if (_vm.VncPort > 0)
                args.AddRange(new[] { "-display", "none" });
            else
                args.AddRange(new[] { "-display", _vm.DisplayType });

            // VNC
            if (_vm.VncPort > 0)
                args.AddRange(new[] { "-vnc", $":{(_vm.VncPort - 5900)}" });

            // Disk with controller
            if (!string.IsNullOrEmpty(_vm.DiskImagePath) && _vm.DiskSizeUnit != "none")
            {
                string controller = _vm.DiskController ?? "VirtIO";
                args.AddRange(new[] { "-drive", $"file=\"{_vm.DiskImagePath}\",format=qcow2,if=none,id=hd0" });
                switch (controller)
                {
                    case "NVMe":
                        args.AddRange(new[] { "-device", "nvme,drive=hd0,serial=AIRVM001" });
                        break;
                    case "SCSI":
                        args.AddRange(new[] { "-device", "lsi53c895a,id=scsi0" });
                        args.AddRange(new[] { "-device", "scsi-hd,drive=hd0,bus=scsi0.0" });
                        break;
                    case "SATA":
                        args.AddRange(new[] { "-device", "ahci,id=ahci0" });
                        args.AddRange(new[] { "-device", "ide-hd,drive=hd0,bus=ahci0.0" });
                        break;
                    default: // VirtIO
                        args.AddRange(new[] { "-device", "virtio-blk-pci,drive=hd0" });
                        break;
                }
            }

            // Boot ISO
            if (!string.IsNullOrEmpty(_vm.BootISOPath))
                args.AddRange(new[] { "-cdrom", $"\"{_vm.BootISOPath}\"" });

            // CD-ROM
            if (!string.IsNullOrEmpty(_vm.CdromImagePath) && string.IsNullOrEmpty(_vm.BootISOPath))
                args.AddRange(new[] { "-cdrom", $"\"{_vm.CdromImagePath}\"" });

            // Floppy
            if (!string.IsNullOrEmpty(_vm.FloppyAPath))
                args.AddRange(new[] { "-fda", $"\"{_vm.FloppyAPath}\"" });
            if (!string.IsNullOrEmpty(_vm.FloppyBPath))
                args.AddRange(new[] { "-fdb", $"\"{_vm.FloppyBPath}\"" });

            // BIOS / ROM
            if (!string.IsNullOrEmpty(_vm.BiosPath))
                args.AddRange(new[] { "-bios", $"\"{_vm.BiosPath}\"" });
            if (!string.IsNullOrEmpty(_vm.RomFilePath))
                args.AddRange(new[] { "-option-rom", $"\"{_vm.RomFilePath}\"" });

            // Network
            switch (_vm.NetworkMode)
            {
                case "user":
                    args.AddRange(new[] { "-netdev", "user,id=net0", "-device", "virtio-net-pci,netdev=net0" });
                    break;
                case "bridge":
                    args.AddRange(new[] { "-netdev", "bridge,id=net0", "-device", "virtio-net-pci,netdev=net0" });
                    break;
                case "host-only":
                    args.AddRange(new[] { "-netdev", "socket,id=net0,listen=:12340", "-device", "virtio-net-pci,netdev=net0" });
                    break;
                case "modem":
                    // Simulate modem via serial
                    args.AddRange(new[] { "-serial", $"mon:stdio" });
                    break;
                case "terminal":
                    args.AddRange(new[] { "-serial", "mon:stdio" });
                    break;
                case "none":
                    args.AddRange(new[] { "-net", "none" });
                    break;
            }

            // Audio with sound card model
            if (_vm.EnableAudio)
            {
                args.AddRange(new[] { "-audiodev", "default,id=audio0" });
                string soundModel = _vm.SoundCardModel ?? "hda";
                switch (soundModel)
                {
                    case "hda":
                        args.AddRange(new[] { "-device", "intel-hda" });
                        args.AddRange(new[] { "-device", "hda-duplex,audiodev=audio0" });
                        break;
                    case "ac97":
                        args.AddRange(new[] { "-device", "AC97,audiodev=audio0" });
                        break;
                    case "es1370":
                        args.AddRange(new[] { "-device", "ES1370,audiodev=audio0" });
                        break;
                    case "sb16":
                        args.AddRange(new[] { "-device", "sb16,audiodev=audio0" });
                        break;
                }
            }

            // USB controller version
            if (_vm.EnableUSB)
            {
                string usbVer = _vm.UsbVersion ?? "3.0";
                if (usbVer == "3.0" || usbVer == "3.1")
                    args.AddRange(new[] { "-device", "qemu-xhci,id=usb0" });
                else
                {
                    args.AddRange(new[] { "-device", "ich9-usb-ehci1,id=usb0" });
                    args.AddRange(new[] { "-device", "ich9-usb-uhci1,masterbus=usb0.0,firstport=0,multifunction=on" });
                }
            }

            // 3D acceleration / GPU
            if (_vm.Enable3DAcceleration)
            {
                int vramKB = (_vm.VramSizeMB > 0 ? _vm.VramSizeMB : 128) * 1024;
                args.AddRange(new[] { "-device", $"virtio-gpu-gl-pci,vgamem_kb={vramKB}" });
            }
            else
            {
                int vramKB = (_vm.VramSizeMB > 0 ? _vm.VramSizeMB : 128) * 1024;
                args.AddRange(new[] { "-device", $"virtio-gpu-pci,vgamem_kb={vramKB}" });
            }

            // Parallel port
            if (_vm.EnableParallelPort)
                args.AddRange(new[] { "-parallel", "stdio" });

            // Shared clipboard & drag-drop via vdagent
            if (_vm.EnableSharedClipboard || _vm.EnableDragDrop)
            {
                args.AddRange(new[] { "-device", "virtio-serial-pci,id=virtio-serial0" });
                args.AddRange(new[] { "-chardev", "spicevmc,id=vdagent,name=vdagent" });
                args.AddRange(new[] { "-device", "virtserialport,chardev=vdagent,name=com.redhat.spice.0" });
            }

            // Guest time sync
            if (_vm.EnableTimeSync)
                args.AddRange(new[] { "-rtc", "base=localtime,clock=host" });

            // Port forwarding (for user mode)
            if (_vm.NetworkMode == "user" && _vm.PortForwards != null && _vm.PortForwards.Count > 0)
            {
                // Rebuild network with port forwards
                args.RemoveAll(s => s == "user,id=net0" || s == "-netdev");
                var pfStr = new StringBuilder("user,id=net0");
                foreach (var pf in _vm.PortForwards)
                    pfStr.Append($",hostfwd={pf.Protocol}::{pf.HostPort}-{pf.GuestIP}:{pf.GuestPort}");
                // Find and update the netdev arg
                for (int i = 0; i < args.Count; i++)
                {
                    if (args[i] == "-netdev" && i + 1 < args.Count && args[i + 1].StartsWith("user"))
                    {
                        args[i + 1] = pfStr.ToString();
                        break;
                    }
                }
            }

            // Monitor (stdin)
            args.AddRange(new[] { "-monitor", "stdio" });

            // Shared folders
            foreach (var sf in _vm.SharedFolders)
            {
                args.AddRange(new[] { "-virtfs",
                    $"local,path=\"{sf.HostPath}\",mount_tag={sf.Name},security_model=mapped-xattr" });
            }

            // Additional args
            args.AddRange(_vm.AdditionalArgs);

            return args;
        }

        // ─── QEMU Binary Discovery ───

        private string FindQEMUBinary()
        {
            var archMap = new Dictionary<VMArchitecture, string>
            {
                { VMArchitecture.X86_64, "qemu-system-x86_64" },
                { VMArchitecture.X86, "qemu-system-i386" },
                { VMArchitecture.ARM, "qemu-system-arm" },
                { VMArchitecture.AArch64, "qemu-system-aarch64" },
                { VMArchitecture.MIPS, "qemu-system-mips" },
                { VMArchitecture.MIPS64, "qemu-system-mips64" },
                { VMArchitecture.MIPSEL, "qemu-system-mipsel" },
                { VMArchitecture.MIPS64EL, "qemu-system-mips64el" },
                { VMArchitecture.PPC, "qemu-system-ppc" },
                { VMArchitecture.PPC64, "qemu-system-ppc64" },
                { VMArchitecture.RISCV32, "qemu-system-riscv32" },
                { VMArchitecture.RISCV64, "qemu-system-riscv64" },
                { VMArchitecture.S390x, "qemu-system-s390x" },
                { VMArchitecture.SPARC, "qemu-system-sparc" },
                { VMArchitecture.SPARC64, "qemu-system-sparc64" },
                { VMArchitecture.M68k, "qemu-system-m68k" },
                { VMArchitecture.Alpha, "qemu-system-alpha" },
                { VMArchitecture.HPPA, "qemu-system-hppa" },
                { VMArchitecture.SH4, "qemu-system-sh4" },
                { VMArchitecture.SH4EB, "qemu-system-sh4eb" },
                { VMArchitecture.MicroBlaze, "qemu-system-microblaze" },
                { VMArchitecture.MicroBlazeEL, "qemu-system-microblazeel" },
                { VMArchitecture.OR1K, "qemu-system-or1k" },
                { VMArchitecture.LoongArch64, "qemu-system-loongarch64" },
                { VMArchitecture.Xtensa, "qemu-system-xtensa" },
                { VMArchitecture.XtensaEB, "qemu-system-xtensaeb" },
                { VMArchitecture.Tricore, "qemu-system-tricore" },
                { VMArchitecture.AVR, "qemu-system-avr" },
                { VMArchitecture.RX, "qemu-system-rx" },
            };

            var binaryName = archMap.GetValueOrDefault(_vm.Architecture, "qemu-system-x86_64");

            // Search paths (Windows)
            var searchPaths = new List<string>
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "qemu", binaryName + ".exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "qemu", binaryName + ".exe"),
                Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "qemu", binaryName + ".exe"),
            };

            // PATH lookup
            var pathEnv = Environment.GetEnvironmentVariable("PATH") ?? "";
            foreach (var p in pathEnv.Split(Path.PathSeparator))
            {
                var candidate = Path.Combine(p, binaryName + ".exe");
                if (File.Exists(candidate)) return candidate;
            }

            foreach (var path in searchPaths)
                if (File.Exists(path)) return path;

            return binaryName + ".exe"; // Fallback
        }

        // ─── Dispose ───

        public void Dispose()
        {
            if (IsRunning) ForceStop();
            _process?.Dispose();
            _cts?.Cancel();
        }
    }
}
