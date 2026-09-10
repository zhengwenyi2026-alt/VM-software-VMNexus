using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using VMStart.Models;

namespace VMStart.UI
{
    public partial class MainWindow : Window
    {
        private ObservableCollection<VirtualMachine> _vms = new();
        private string _vmDirectory;
        private AppMode _currentMode = AppMode.Standard;

        public MainWindow()
        {
            InitializeComponent();
            _vmDirectory = GetDefaultVMDirectory();
            VMList.ItemsSource = _vms;
            RefreshVMList();
            UpdateStatusBar();
            UpdateModeButtons();
        }

        private string GetDefaultVMDirectory()
        {
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            var dir = Path.Combine(appData, "AirVM", "VirtualMachines");
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
            return dir;
        }

        private void RefreshVMList()
        {
            _vms.Clear();
            if (!Directory.Exists(_vmDirectory)) return;
            foreach (var dir in Directory.GetDirectories(_vmDirectory))
            {
                var vm = new VirtualMachine();
                if (vm.LoadFromBundle(dir))
                    _vms.Add(vm);
            }
            VMList.ItemsSource = _vms.OrderBy(v => v.Name).ToList();
        }

        private void UpdateStatusBar()
        {
            var total = _vms.Count;
            var running = _vms.Count(v => v.Status == VMStatus.Running);
            StatusBar.Text = $"{total} VMs ({running} running) • QEMU Engine";
        }

        private void UpdateContentVisibility()
        {
            var selected = VMList.SelectedItem as VirtualMachine;
            if (selected != null)
            {
                WelcomePanel.Visibility = Visibility.Collapsed;
                DetailsPanel.Visibility = Visibility.Visible;
                UpdateDetails(selected);
            }
            else
            {
                WelcomePanel.Visibility = Visibility.Visible;
                DetailsPanel.Visibility = Visibility.Collapsed;
            }
        }

        private void UpdateDetails(VirtualMachine vm)
        {
            DetailName.Text = vm.Name;
            DetailArch.Text = vm.ArchitectureDisplayName;
            DetailStatus.Text = vm.StatusDisplayName;
            DetailStatusBadge.Background = vm.StatusColor;

            DetailCPU.Text = $"{vm.CpuModel} ({vm.CpuCores} cores)";
            DetailMemory.Text = $"{vm.MemoryValue} {vm.MemoryUnit}";
            DetailDisk.Text = vm.DiskSizeUnit == "none" ? "No disk" : $"{vm.DiskSizeValue} {vm.DiskSizeUnit}";
            DetailNetwork.Text = vm.NetworkMode;
            DetailDisplay.Text = vm.DisplayType;
            DetailStatusInfo.Text = vm.StatusDisplayName;
            DetailNotes.Text = string.IsNullOrEmpty(vm.Notes) ? "No notes" : vm.Notes;

            // Show/hide notes based on mode
            NotesCard.Visibility = _currentMode == AppMode.Simple ? Visibility.Collapsed : Visibility.Visible;

            // Update start button
            StartBtn.Content = vm.Status == VMStatus.Running ? "⏹ Stop" : "▶ Start";
        }

        // ─── Mode Switching ───
        private void ModeSwitch_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string tag)
            {
                _currentMode = (AppMode)int.Parse(tag);
                UpdateModeButtons();
                if (VMList.SelectedItem is VirtualMachine vm) UpdateDetails(vm);
            }
        }

        private void UpdateModeButtons()
        {
            var primary = (SolidColorBrush)FindResource("PrimaryBrush");
            SimpleBtn.Background = _currentMode == AppMode.Simple ? primary : Brushes.Transparent;
            SimpleBtn.Foreground = _currentMode == AppMode.Simple ? Brushes.White : Brushes.Black;
            StandardBtn.Background = _currentMode == AppMode.Standard ? primary : Brushes.Transparent;
            StandardBtn.Foreground = _currentMode == AppMode.Standard ? Brushes.White : Brushes.Black;
            AdvancedBtn.Background = _currentMode == AppMode.Advanced ? primary : Brushes.Transparent;
            AdvancedBtn.Foreground = _currentMode == AppMode.Advanced ? Brushes.White : Brushes.Black;
        }

        // ─── Search ───
        private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            var query = SearchBox.Text.ToLower();
            if (string.IsNullOrEmpty(query))
            {
                VMList.ItemsSource = _vms.OrderBy(v => v.Name).ToList();
            }
            else
            {
                VMList.ItemsSource = _vms
                    .Where(v => v.Name.ToLower().Contains(query) || v.ArchitectureDisplayName.ToLower().Contains(query))
                    .OrderBy(v => v.Name).ToList();
            }
        }

        // ─── Actions ───
        private void AddVM_Click(object sender, RoutedEventArgs e)
        {
            var vm = new VirtualMachine { Name = "New Virtual Machine" };
            var bundlePath = Path.Combine(_vmDirectory, $"{vm.Id}.airvm");
            vm.BundlePath = bundlePath;
            var wizard = new ConfigWizardWindow(vm, isNew: true);
            wizard.Owner = this;
            if (wizard.ShowDialog() == true)
            {
                vm.SaveToBundle();
                RefreshVMList();
                UpdateStatusBar();
            }
        }

        private void OpenVM_Click(object sender, RoutedEventArgs e)
        {
            // TODO: Open file dialog to import VM
        }

        private void RemoveVM_Click(object sender, RoutedEventArgs e)
        {
            if (VMList.SelectedItem is VirtualMachine vm)
            {
                var result = MessageBox.Show(
                    "This action cannot be undone. The virtual machine and its data will be permanently removed.",
                    "Delete Virtual Machine?",
                    MessageBoxButton.OKCancel, MessageBoxImage.Warning);
                if (result == MessageBoxResult.OK)
                {
                    try { Directory.Delete(vm.BundlePath, true); } catch { }
                    _vms.Remove(vm);
                    UpdateContentVisibility();
                    UpdateStatusBar();
                }
            }
        }

        private void EditVM_Click(object sender, RoutedEventArgs e)
        {
            if (VMList.SelectedItem is VirtualMachine vm)
            {
                var wizard = new ConfigWizardWindow(vm, isNew: false);
                wizard.Owner = this;
                if (wizard.ShowDialog() == true)
                {
                    vm.SaveToBundle();
                    UpdateDetails(vm);
                    UpdateStatusBar();
                }
            }
        }

        private void StartVM_Click(object sender, RoutedEventArgs e)
        {
            if (VMList.SelectedItem is VirtualMachine vm)
            {
                var console = new ConsoleWindow(vm);
                console.Show();
                console.StartVM();
            }
        }

        private void VMList_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            UpdateContentVisibility();
        }

        // ─── Context Menu Handlers ───

        private VirtualMachine GetContextVM() => VMList.SelectedItem as VirtualMachine;

        private void CtxStart_Click(object sender, RoutedEventArgs e) => StartVM_Click(sender, e);

        private void CtxStop_Click(object sender, RoutedEventArgs e)
        {
            // Stop is handled via console window
        }

        private void CtxPause_Click(object sender, RoutedEventArgs e)
        {
            // Pause is handled via console window
        }

        private void CtxConsole_Click(object sender, RoutedEventArgs e)
        {
            if (GetContextVM() is VirtualMachine vm)
            {
                var console = new ConsoleWindow(vm);
                console.Show();
                if (vm.Status != VMStatus.Running) console.StartVM();
            }
        }

        private void CtxFavorite_Click(object sender, RoutedEventArgs e)
        {
            if (GetContextVM() is VirtualMachine vm)
            {
                vm.IsFavorite = !vm.IsFavorite;
                vm.SaveToBundle();
                RefreshVMList();
            }
        }

        private void CtxSetGroup_Click(object sender, RoutedEventArgs e)
        {
            if (GetContextVM() is VirtualMachine vm)
            {
                var dialog = new Window { Title = "Set Group", Width = 300, Height = 140, WindowStartupLocation = WindowStartupLocation.CenterOwner, Owner = this };
                var panel = new StackPanel { Margin = new Thickness(16) };
                var tb = new TextBox { Text = vm.Group ?? "", Margin = new Thickness(0, 8, 0, 8) };
                var okBtn = new Button { Content = "OK", Width = 80, HorizontalAlignment = HorizontalAlignment.Right };
                okBtn.Click += (_, _) => { vm.Group = tb.Text; vm.SaveToBundle(); RefreshVMList(); dialog.Close(); };
                panel.Children.Add(new TextBlock { Text = "Group name:" });
                panel.Children.Add(tb);
                panel.Children.Add(okBtn);
                dialog.Content = panel;
                dialog.ShowDialog();
            }
        }

        private void CtxTakeSnapshot_Click(object sender, RoutedEventArgs e)
        {
            if (GetContextVM() is VirtualMachine vm)
            {
                var dialog = new Window { Title = "Take Snapshot", Width = 300, Height = 140, WindowStartupLocation = WindowStartupLocation.CenterOwner, Owner = this };
                var panel = new StackPanel { Margin = new Thickness(16) };
                var tb = new TextBox { Text = $"snapshot-{vm.Snapshots.Count + 1}", Margin = new Thickness(0, 8, 0, 8) };
                var okBtn = new Button { Content = "Save", Width = 80, HorizontalAlignment = HorizontalAlignment.Right };
                okBtn.Click += (_, _) =>
                {
                    vm.Snapshots.Add(new SnapshotInfo { Name = tb.Text, Date = DateTime.Now.ToString("yyyy-MM-dd HH:mm"), Type = "manual" });
                    vm.SaveToBundle();
                    dialog.Close();
                };
                panel.Children.Add(new TextBlock { Text = "Snapshot name:" });
                panel.Children.Add(tb);
                panel.Children.Add(okBtn);
                dialog.Content = panel;
                dialog.ShowDialog();
            }
        }

        private void CtxRestoreSnapshot_Click(object sender, RoutedEventArgs e)
        {
            if (GetContextVM() is VirtualMachine vm && vm.Snapshots.Count > 0)
            {
                var names = vm.Snapshots.Select(s => $"{s.Name} ({s.Date})").ToArray();
                var result = MessageBox.Show($"Restore: {names[0]}?", "Restore Snapshot", MessageBoxButton.OKCancel);
                if (result == MessageBoxResult.OK)
                {
                    // Would call qemu-img snapshot -a via process
                    MessageBox.Show("Snapshot restore requires VM to be stopped.", "Info");
                }
            }
        }

        private void CtxDeleteSnapshot_Click(object sender, RoutedEventArgs e)
        {
            if (GetContextVM() is VirtualMachine vm && vm.Snapshots.Count > 0)
            {
                var result = MessageBox.Show($"Delete snapshot '{vm.Snapshots[0].Name}'?", "Delete Snapshot", MessageBoxButton.OKCancel);
                if (result == MessageBoxResult.OK)
                {
                    vm.Snapshots.RemoveAt(0);
                    vm.SaveToBundle();
                }
            }
        }

        private void CtxFullClone_Click(object sender, RoutedEventArgs e)
        {
            if (GetContextVM() is VirtualMachine vm)
            {
                var clone = new VirtualMachine
                {
                    Name = $"{vm.Name} (Clone)",
                    Architecture = vm.Architecture,
                    MachineType = vm.MachineType,
                    CpuModel = vm.CpuModel,
                    CpuCores = vm.CpuCores,
                    CpuSockets = vm.CpuSockets,
                    CpuCoresPerSocket = vm.CpuCoresPerSocket,
                    MemoryValue = vm.MemoryValue,
                    MemoryUnit = vm.MemoryUnit,
                    DiskController = vm.DiskController,
                    NetworkMode = vm.NetworkMode,
                    EnableAudio = vm.EnableAudio,
                    EnableUSB = vm.EnableUSB,
                    UsbVersion = vm.UsbVersion
                };
                clone.BundlePath = Path.Combine(_vmDirectory, $"{clone.Id}.airvm");
                Directory.CreateDirectory(clone.BundlePath);

                // Copy disk image
                var srcDisk = Path.Combine(vm.BundlePath, "disk.qcow2");
                var dstDisk = Path.Combine(clone.BundlePath, "disk.qcow2");
                if (File.Exists(srcDisk)) File.Copy(srcDisk, dstDisk);
                clone.DiskImagePath = dstDisk;

                clone.SaveToBundle();
                RefreshVMList();
                MessageBox.Show($"Full clone created: {clone.Name}", "Clone Complete");
            }
        }

        private void CtxLinkedClone_Click(object sender, RoutedEventArgs e)
        {
            if (GetContextVM() is VirtualMachine vm)
            {
                var clone = new VirtualMachine
                {
                    Name = $"{vm.Name} (Linked)",
                    Architecture = vm.Architecture,
                    MachineType = vm.MachineType,
                    CpuCores = vm.CpuCores,
                    MemoryValue = vm.MemoryValue,
                    MemoryUnit = vm.MemoryUnit,
                    DiskController = vm.DiskController,
                    NetworkMode = vm.NetworkMode
                };
                clone.BundlePath = Path.Combine(_vmDirectory, $"{clone.Id}.airvm");
                Directory.CreateDirectory(clone.BundlePath);
                // Linked clone references original disk
                clone.DiskImagePath = vm.DiskImagePath;
                clone.SaveToBundle();
                RefreshVMList();
                MessageBox.Show($"Linked clone created: {clone.Name}", "Clone Complete");
            }
        }

        private void CtxExportOVF_Click(object sender, RoutedEventArgs e)
        {
            if (GetContextVM() is VirtualMachine vm)
            {
                var dialog = new Microsoft.Win32.SaveFileDialog
                {
                    Filter = "OVF Files|*.ovf",
                    FileName = $"{vm.Name}.ovf",
                    Title = "Export OVF"
                };
                if (dialog.ShowDialog() == true)
                {
                    var ovf = new StringBuilder();
                    ovf.AppendLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
                    ovf.AppendLine("<Envelope xmlns=\"http://schemas.dmtf.org/ovf/envelope/1\">");
                    ovf.AppendLine($"  <VirtualSystem ovf:id=\"{vm.Name}\">");
                    ovf.AppendLine($"    <Name>{vm.Name}</Name>");
                    ovf.AppendLine($"    <OperatingSystemSection><Description>{vm.ArchitectureDisplayName}</Description></OperatingSystemSection>");
                    ovf.AppendLine($"    <VirtualHardwareSection>");
                    ovf.AppendLine($"      <Item><rasd:ElementName>CPU</rasd:ElementName><rasd:VirtualQuantity>{vm.CpuCores}</rasd:VirtualQuantity></Item>");
                    ovf.AppendLine($"      <Item><rasd:ElementName>Memory</rasd:ElementName><rasd:VirtualQuantity>{vm.MemoryValue}</rasd:VirtualQuantity></Item>");
                    ovf.AppendLine($"    </VirtualHardwareSection>");
                    ovf.AppendLine("  </VirtualSystem>");
                    ovf.AppendLine("</Envelope>");
                    File.WriteAllText(dialog.FileName, ovf.ToString());
                    MessageBox.Show($"OVF exported to {dialog.FileName}", "Export Complete");
                }
            }
        }

        private void CtxEncrypt_Click(object sender, RoutedEventArgs e)
        {
            if (GetContextVM() is VirtualMachine vm)
            {
                vm.IsEncrypted = !vm.IsEncrypted;
                vm.SaveToBundle();
                MessageBox.Show(vm.IsEncrypted ? "VM marked as encrypted." : "VM encryption removed.", "Encryption");
            }
        }

        // ─── Drag & Drop ───

        private void VMList_DragOver(object sender, DragEventArgs e)
        {
            e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
            e.Handled = true;
        }

        private void VMList_Drop(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                var files = (string[])e.Data.GetData(DataFormats.FileDrop);
                foreach (var file in files)
                {
                    var ext = Path.GetExtension(file)?.ToLower();
                    if (ext == ".airvm" && Directory.Exists(file))
                    {
                        var vm = new VirtualMachine();
                        if (vm.LoadFromBundle(file))
                        {
                            _vms.Add(vm);
                        }
                    }
                    else if (ext == ".qcow2" || ext == ".vmdk" || ext == ".vdi" || ext == ".vhd")
                    {
                        var vm = new VirtualMachine { Name = Path.GetFileNameWithoutExtension(file), DiskImagePath = file };
                        vm.BundlePath = Path.Combine(_vmDirectory, $"{vm.Id}.airvm");
                        vm.SaveToBundle();
                        _vms.Add(vm);
                    }
                    else if (ext == ".iso" || ext == ".img")
                    {
                        var vm = new VirtualMachine { Name = Path.GetFileNameWithoutExtension(file), BootISOPath = file };
                        vm.BundlePath = Path.Combine(_vmDirectory, $"{vm.Id}.airvm");
                        vm.SaveToBundle();
                        _vms.Add(vm);
                    }
                }
                UpdateStatusBar();
            }
        }
    }
}
