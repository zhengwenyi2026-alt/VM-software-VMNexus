using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using AirVM.Models;

namespace AirVM.UI
{
    public partial class ConfigWizardWindow : Window
    {
        private readonly VirtualMachine _vm;
        private readonly bool _isNew;
        private int _currentStep;
        private AppMode _mode = AppMode.Standard;

        private readonly List<string> _stepsAll = new() { "Basic", "Hardware", "Storage", "Network", "Display", "Summary" };
        private readonly List<Panel> _stepPanels = new();

        // Mode-specific step visibility
        private List<string> ActiveSteps => _mode switch
        {
            AppMode.Simple => new List<string> { "Basic", "Storage", "Summary" },
            AppMode.Advanced => _stepsAll,
            _ => _stepsAll // Standard shows all
        };

        public ConfigWizardWindow(VirtualMachine vm, bool isNew)
        {
            InitializeComponent();
            _vm = vm;
            _isNew = isNew;

            _stepPanels.AddRange(new Panel[] { StepBasic, StepHardware, StepStorage, StepNetwork, StepDisplay, StepSummary });

            PopulateControls();
            LoadFromVM();
            RefreshStepList();
            ShowStep(0);
            UpdateModeButtons();
        }

        // ─── Populate Dropdowns ───
        private void PopulateControls()
        {
            // Architectures
            ArchCombo.ItemsSource = Enum.GetValues<VMArchitecture>()
                .Select(a => new { Value = a, Display = a.ToString() }).ToList();
            ArchCombo.DisplayMemberPath = "Display";

            // Machine Types
            MachineTypeCombo.ItemsSource = new[] { "default", "pc", "q35", "virt", "mac99", "g3beige", "malta", "none" };

            // CPU Models
            CpuCombo.ItemsSource = new[] { "default", "qemu64", "kvm64", "host", "core2duo", "pentium3", "cortex-a53", "cortex-a72", "max" };

            // CPU Cores
            CoresCombo.ItemsSource = new[] { "1", "2", "4", "6", "8", "12", "16", "32" };

            // Memory Units
            MemoryUnitCombo.ItemsSource = new[] { "MB", "GB" };
            DiskUnitCombo.ItemsSource = new[] { "GB", "TB", "none" };

            // Network Modes
            NetworkModeCombo.ItemsSource = new[]
            {
                "NAT (user)", "Bridge", "Host-only", "Virtual Modem (dial-up)", "Terminal", "none"
            };

            // Modem Speeds
            ModemSpeedCombo.ItemsSource = new[] { "2400", "9600", "14400", "28800", "56000" };

            // Display Backends
            DisplayCombo.ItemsSource = new[] { "sdl", "gtk", "cocoa", "none", "vnc" };
        }

        private void LoadFromVM()
        {
            VMNameBox.Text = _vm.Name;
            ArchCombo.SelectedValue = _vm.Architecture;
            MachineTypeCombo.SelectedItem = _vm.MachineType;
            CpuCombo.SelectedItem = _vm.CpuModel;
            CoresCombo.SelectedItem = _vm.CpuCores.ToString();
            MemoryBox.Text = _vm.MemoryValue.ToString();
            MemoryUnitCombo.SelectedItem = _vm.MemoryUnit;
            DiskSizeBox.Text = _vm.DiskSizeValue.ToString();
            DiskUnitCombo.SelectedItem = _vm.DiskSizeUnit;
            BootISOBox.Text = _vm.BootISOPath;
            CDROMBox.Text = _vm.CdromImagePath;
            NetworkModeCombo.SelectedIndex = NetworkModeToIndex(_vm.NetworkMode);
            DisplayCombo.SelectedItem = _vm.DisplayType;
            AudioCheck.IsChecked = _vm.EnableAudio;
            USBCheck.IsChecked = _vm.EnableUSB;
            AccelCheck.IsChecked = _vm.EnableAcceleration;
            NotesBox.Text = _vm.Notes;

            // Extended
            ModemCheck.IsChecked = _vm.EnableModem;
            ModemSpeedCombo.SelectedItem = _vm.ModemSpeed;
            TerminalCheck.IsChecked = _vm.EnableTerminal;
            UnityCheck.IsChecked = _vm.EnableUnity;
        }

        private int NetworkModeToIndex(string mode) => mode switch
        {
            "bridge" => 1,
            "host-only" => 2,
            "modem" => 3,
            "terminal" => 4,
            "none" => 5,
            _ => 0 // user/NAT
        };

        // ─── Step Navigation ───
        private void RefreshStepList()
        {
            StepList.ItemsSource = ActiveSteps;
        }

        private void ShowStep(int step)
        {
            _currentStep = Math.Clamp(step, 0, ActiveSteps.Count - 1);

            // Map active step name to panel index
            var stepName = ActiveSteps[_currentStep];
            var panelIndex = _stepsAll.IndexOf(stepName);

            for (int i = 0; i < _stepPanels.Count; i++)
                _stepPanels[i].Visibility = Visibility.Collapsed;

            if (panelIndex >= 0 && panelIndex < _stepPanels.Count)
                _stepPanels[panelIndex].Visibility = Visibility.Visible;

            // Update summary
            if (stepName == "Summary") BuildSummary();

            // Update buttons
            BackBtn.IsEnabled = _currentStep > 0;
            NextBtn.Content = _currentStep == ActiveSteps.Count - 1 ? "Finish ✓" : "Next →";

            // Highlight step in list
            StepList.SelectedIndex = _currentStep;

            // Update network visibility for mode
            if (stepName == "Network") UpdateNetworkForMode();
        }

        private void StepList_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (StepList.SelectedIndex >= 0) ShowStep(StepList.SelectedIndex);
        }

        private void Back_Click(object sender, RoutedEventArgs e) => ShowStep(_currentStep - 1);

        private void Next_Click(object sender, RoutedEventArgs e)
        {
            if (_currentStep == ActiveSteps.Count - 1)
            {
                SaveToVM();
                DialogResult = true;
                Close();
            }
            else
            {
                ShowStep(_currentStep + 1);
            }
        }

        private void Cancel_Click(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }

        // ─── Mode Switching ───
        private void Mode_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string tag)
            {
                _mode = (AppMode)int.Parse(tag);
                UpdateModeButtons();
                RefreshStepList();
                // Clamp current step to new active steps
                if (_currentStep >= ActiveSteps.Count)
                    _currentStep = ActiveSteps.Count - 1;
                ShowStep(_currentStep);
            }
        }

        private void UpdateModeButtons()
        {
            var primary = new SolidColorBrush(Color.FromRgb(37, 99, 235));
            ModeSimple.Background = _mode == AppMode.Simple ? primary : Brushes.Transparent;
            ModeSimple.Foreground = _mode == AppMode.Simple ? Brushes.White : Brushes.Black;
            ModeStandard.Background = _mode == AppMode.Standard ? primary : Brushes.Transparent;
            ModeStandard.Foreground = _mode == AppMode.Standard ? Brushes.White : Brushes.Black;
            ModeAdvanced.Background = _mode == AppMode.Advanced ? primary : Brushes.Transparent;
            ModeAdvanced.Foreground = _mode == AppMode.Advanced ? Brushes.White : Brushes.Black;
        }

        private void UpdateNetworkForMode()
        {
            // Reduce network options for Simple mode
            if (_mode == AppMode.Simple)
            {
                NetworkModeCombo.ItemsSource = new[] { "NAT (user)", "Bridge", "none" };
            }
            else
            {
                NetworkModeCombo.ItemsSource = new[]
                {
                    "NAT (user)", "Bridge", "Host-only", "Virtual Modem (dial-up)", "Terminal", "none"
                };
            }

            // Show/hide advanced options
            ModemPanel.Visibility = _mode == AppMode.Advanced ? Visibility.Visible : Visibility.Collapsed;
            TerminalCheck.Visibility = _mode == AppMode.Advanced ? Visibility.Visible : Visibility.Collapsed;
            UnityCheck.Visibility = _mode >= AppMode.Standard ? Visibility.Visible : Visibility.Collapsed;
        }

        // ─── File Browsers ───
        private void BrowseBootISO(object sender, RoutedEventArgs e)
        {
            var dlg = new Microsoft.Win32.OpenFileDialog
            {
                Title = "Select Boot ISO",
                Filter = "ISO Images (*.iso)|*.iso|IMG Files (*.img)|*.img|All Files (*.*)|*.*"
            };
            if (dlg.ShowDialog() == true) BootISOBox.Text = dlg.FileName;
        }

        private void BrowseCDROM(object sender, RoutedEventArgs e)
        {
            var dlg = new Microsoft.Win32.OpenFileDialog
            {
                Title = "Select CD-ROM Image",
                Filter = "ISO Images (*.iso)|*.iso|IMG Files (*.img)|*.img|All Files (*.*)|*.*"
            };
            if (dlg.ShowDialog() == true) CDROMBox.Text = dlg.FileName;
        }

        // ─── Save / Summary ───
        private void SaveToVM()
        {
            _vm.Name = VMNameBox.Text.Trim();
            if (ArchCombo.SelectedValue is VMArchitecture arch) _vm.Architecture = arch;
            _vm.MachineType = MachineTypeCombo.SelectedItem?.ToString() ?? "default";
            _vm.CpuModel = CpuCombo.SelectedItem?.ToString() ?? "default";
            if (int.TryParse(CoresCombo.SelectedItem?.ToString(), out var cores)) _vm.CpuCores = cores;
            if (int.TryParse(MemoryBox.Text, out var mem)) _vm.MemoryValue = mem;
            _vm.MemoryUnit = MemoryUnitCombo.SelectedItem?.ToString() ?? "MB";
            if (int.TryParse(DiskSizeBox.Text, out var disk)) _vm.DiskSizeValue = disk;
            _vm.DiskSizeUnit = DiskUnitCombo.SelectedItem?.ToString() ?? "GB";
            _vm.BootISOPath = BootISOBox.Text;
            _vm.CdromImagePath = CDROMBox.Text;
            _vm.NetworkMode = IndexToNetworkMode(NetworkModeCombo.SelectedIndex);
            _vm.DisplayType = DisplayCombo.SelectedItem?.ToString() ?? "sdl";
            _vm.EnableAudio = AudioCheck.IsChecked == true;
            _vm.EnableUSB = USBCheck.IsChecked == true;
            _vm.EnableAcceleration = AccelCheck.IsChecked == true;
            _vm.Notes = NotesBox.Text;
            _vm.LastUsedAt = DateTime.Now;

            // Extended
            _vm.EnableModem = ModemCheck.IsChecked == true;
            _vm.ModemSpeed = ModemSpeedCombo.SelectedItem?.ToString() ?? "56000";
            _vm.EnableTerminal = TerminalCheck.IsChecked == true;
            _vm.EnableUnity = UnityCheck.IsChecked == true;
        }

        private string IndexToNetworkMode(int index) => index switch
        {
            1 => "bridge",
            2 => "host-only",
            3 => "modem",
            4 => "terminal",
            5 => "none",
            _ => "user"
        };

        private void BuildSummary()
        {
            var arch = ArchCombo.SelectedValue is VMArchitecture a ? a.ToString() : "?";
            var lines = new[]
            {
                $"Name:        {VMNameBox.Text}",
                $"Architecture: {arch}",
                $"Machine:     {MachineTypeCombo.SelectedItem}",
                $"CPU:         {CpuCombo.SelectedItem} ({CoresCombo.SelectedItem} cores)",
                $"Memory:      {MemoryBox.Text} {MemoryUnitCombo.SelectedItem}",
                $"Disk:        {DiskSizeBox.Text} {DiskUnitCombo.SelectedItem}",
                $"Network:     {NetworkModeCombo.SelectedItem}",
                $"Display:     {DisplayCombo.SelectedItem}",
                $"Audio:       {(AudioCheck.IsChecked == true ? "Yes" : "No")}",
                $"USB:         {(USBCheck.IsChecked == true ? "Yes" : "No")}",
                $"Acceleration:{(AccelCheck.IsChecked == true ? "Yes" : "No")}",
            };
            SummaryText.Text = string.Join("\n", lines);
        }
    }
}
