using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using AirVM.Models;
using AirVM.Engine;

namespace AirVM.UI
{
    public partial class ConsoleWindow : Window
    {
        private readonly VirtualMachine _vm;
        private QEMUEngine _engine;
        private bool _isPaused;
        private readonly StringBuilder _logBuffer = new();
        private int _activeTab; // 0=display, 1=log, 2=serial
        private const int VNCPort = 5900;
        private const int SerialPort = 4321;

        public ConsoleWindow(VirtualMachine vm)
        {
            InitializeComponent();
            _vm = vm;
            Title = $"{vm.Name} — AirVM Console";
            ToolbarVMName.Text = vm.Name;

            _engine = new QEMUEngine(vm);
            _engine.OnOutput += AppendLog;
            _engine.OnError += AppendLog;
            _engine.OnStarted += () => Dispatcher.Invoke(() => OnVMStarted());
            _engine.OnStopped += (code) => Dispatcher.Invoke(() => OnVMStopped(code));

            Closed += (s, e) =>
            {
                VNCViewer?.Dispose();
                SerialTerminal?.Dispose();
                if (_engine.IsRunning) _engine.ForceStop();
            };
        }

        public void StartVM()
        {
            ShowSplash("Starting virtual machine...");

            // Configure VNC display and serial port
            _vm.DisplayType = "none";
            _vm.VncPort = VNCPort;
            _vm.AdditionalArgs.Add("-serial");
            _vm.AdditionalArgs.Add($"telnet:127.0.0.1:{SerialPort},server,nowait");

            try
            {
                _engine.Start();
            }
            catch (Exception ex)
            {
                HideSplash();
                AppendLog($"[ERROR] {ex.Message}");
                StatusBar.Text = "Failed to start";
            }
        }

        private void OnVMStarted()
        {
            HideSplash();
            StartStopBtn.Content = "⏹ Stop";
            PauseBtn.IsEnabled = true;
            CaptureBtn.IsEnabled = true;
            StatusBar.Text = $"Running (PID: {_engine.ProcessId})";
            AppendLog("[AirVM] Virtual machine started successfully.");

            // Connect VNC viewer (delayed for QEMU to start listening)
            var timer = new System.Windows.Threading.DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(1.0)
            };
            timer.Tick += (s, args) =>
            {
                timer.Stop();
                try
                {
                    VNCViewer.Connect("127.0.0.1", VNCPort);
                    AppendLog($"[VNC] Connecting to 127.0.0.1:{VNCPort}...");
                }
                catch (Exception ex)
                {
                    AppendLog($"[VNC] Connection failed: {ex.Message}");
                }
            };
            timer.Start();

            // Connect serial terminal (slightly later)
            var serialTimer = new System.Windows.Threading.DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(1.5)
            };
            serialTimer.Tick += (s, args) =>
            {
                serialTimer.Stop();
                try { SerialTerminal.Connect("127.0.0.1", SerialPort); }
                catch { }
            };
            serialTimer.Start();

            VNCViewer.OnConnected = () =>
            {
                AppendLog("[VNC] Display connected");
                StatusBar.Text = $"Running ({VNCViewer.FramebufferWidth}x{VNCViewer.FramebufferHeight})";
            };
            VNCViewer.OnDisconnected = () => AppendLog("[VNC] Display disconnected");
        }

        private void OnVMStopped(int exitCode)
        {
            StartStopBtn.Content = "▶ Start";
            PauseBtn.IsEnabled = false;
            CaptureBtn.IsEnabled = false;
            PauseBtn.Content = "⏸ Pause";
            _isPaused = false;
            StatusBar.Text = $"Stopped (exit code: {exitCode})";
            AppendLog($"[AirVM] Virtual machine stopped (exit code: {exitCode}).");
        }

        // ─── Toolbar Actions ───
        private void ToggleStartStop(object sender, RoutedEventArgs e)
        {
            if (_engine.IsRunning)
            {
                AppendLog("[AirVM] Sending shutdown signal...");
                _engine.Stop();
                StatusBar.Text = "Stopping...";
            }
            else
            {
                StartVM();
            }
        }

        private void TogglePause(object sender, RoutedEventArgs e)
        {
            if (!_engine.IsRunning) return;
            if (_isPaused)
            {
                _engine.Resume();
                PauseBtn.Content = "⏸ Pause";
                _isPaused = false;
                StatusBar.Text = "Running";
                AppendLog("[AirVM] Resumed.");
            }
            else
            {
                _engine.Pause();
                PauseBtn.Content = "▶ Resume";
                _isPaused = true;
                StatusBar.Text = "Paused";
                AppendLog("[AirVM] Paused.");
            }
        }

        private void ShowMediaMenu(object sender, RoutedEventArgs e)
        {
            var menu = new System.Windows.Controls.ContextMenu();

            var cdromItem = new MenuItem { Header = "💿 Change CD-ROM..." };
            cdromItem.Click += (s, args) =>
            {
                var dlg = new Microsoft.Win32.OpenFileDialog
                {
                    Title = "Select CD-ROM Image",
                    Filter = "ISO Images (*.iso)|*.iso|IMG Files (*.img)|*.img|All Files (*.*)|*.*"
                };
                if (dlg.ShowDialog() == true)
                {
                    _vm.CdromImagePath = dlg.FileName;
                    _engine.SendMonitorCommand($"change cdrom \"{dlg.FileName}\"");
                    AppendLog($"[Media] CD-ROM changed to: {Path.GetFileName(dlg.FileName)}");
                }
            };

            var floppyItem = new MenuItem { Header = "💾 Change Floppy A..." };
            floppyItem.Click += (s, args) =>
            {
                var dlg = new Microsoft.Win32.OpenFileDialog
                {
                    Title = "Select Floppy Image",
                    Filter = "Floppy Images (*.img, *.ima)|*.img;*.ima|All Files (*.*)|*.*"
                };
                if (dlg.ShowDialog() == true)
                {
                    _vm.FloppyAPath = dlg.FileName;
                    _engine.SendMonitorCommand($"change floppy0 \"{dlg.FileName}\"");
                    AppendLog($"[Media] Floppy A changed to: {Path.GetFileName(dlg.FileName)}");
                }
            };

            var ejectCdrom = new MenuItem { Header = "⏏ Eject CD-ROM" };
            ejectCdrom.Click += (s, args) =>
            {
                _vm.CdromImagePath = "";
                _engine.SendMonitorCommand("eject cdrom");
                AppendLog("[Media] CD-ROM ejected.");
            };

            var ejectFloppy = new MenuItem { Header = "⏏ Eject Floppy A" };
            ejectFloppy.Click += (s, args) =>
            {
                _vm.FloppyAPath = "";
                _engine.SendMonitorCommand("eject floppy0");
                AppendLog("[Media] Floppy A ejected.");
            };

            menu.Items.Add(cdromItem);
            menu.Items.Add(ejectCdrom);
            menu.Items.Add(new Separator());
            menu.Items.Add(floppyItem);
            menu.Items.Add(ejectFloppy);

            if (sender is System.Windows.Controls.Button btn)
            {
                menu.PlacementTarget = btn;
                menu.IsOpen = true;
            }
        }

        private void TakeScreenshot(object sender, RoutedEventArgs e)
        {
            if (!_engine.IsRunning) return;
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.MyPictures), "AirVM");
            Directory.CreateDirectory(dir);
            var path = Path.Combine(dir, $"screenshot_{DateTime.Now:yyyyMMdd_HHmmss}.ppm");
            _engine.SendMonitorCommand($"screendump \"{path}\"");
            AppendLog($"[Capture] Screenshot saved to: {path}");
            StatusBar.Text = "Screenshot captured";
        }

        private void ToggleFullscreen(object sender, RoutedEventArgs e)
        {
            if (WindowState == WindowState.Normal)
            {
                WindowStyle = WindowStyle.None;
                WindowState = WindowState.Maximized;
                ResizeMode = ResizeMode.NoResize;
            }
            else
            {
                WindowStyle = WindowStyle.SingleBorderWindow;
                WindowState = WindowState.Normal;
                ResizeMode = ResizeMode.CanResize;
            }
        }

        // ─── Tab Switching ───
        private void SwitchTab(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Button btn && btn.Tag is string tag)
            {
                _activeTab = int.Parse(tag);
                DisplayPanel.Visibility = _activeTab == 0 ? Visibility.Visible : Visibility.Collapsed;
                LogView.Visibility = _activeTab == 1 ? Visibility.Visible : Visibility.Collapsed;
                SerialTerminal.Visibility = _activeTab == 2 ? Visibility.Visible : Visibility.Collapsed;
                UpdateTabHighlight();
            }
        }

        private void UpdateTabHighlight()
        {
            var active = new SolidColorBrush(Color.FromRgb(37, 99, 235));
            var inactive = Brushes.Transparent;
            TabDisplay.Background = _activeTab == 0 ? active : inactive;
            TabDisplay.Foreground = _activeTab == 0 ? Brushes.White : new SolidColorBrush(Color.FromRgb(170, 170, 170));
            TabLog.Background = _activeTab == 1 ? active : inactive;
            TabLog.Foreground = _activeTab == 1 ? Brushes.White : new SolidColorBrush(Color.FromRgb(170, 170, 170));
            TabSerial.Background = _activeTab == 2 ? active : inactive;
            TabSerial.Foreground = _activeTab == 2 ? Brushes.White : new SolidColorBrush(Color.FromRgb(170, 170, 170));
        }

        // ─── Splash Screen ───
        private void ShowSplash(string subtitle)
        {
            SplashSubtitle.Text = subtitle;
            SplashOverlay.Visibility = Visibility.Visible;
        }

        private void HideSplash()
        {
            SplashOverlay.Visibility = Visibility.Collapsed;
        }

        // ─── Logging ───
        private void AppendLog(string text)
        {
            Dispatcher.Invoke(() =>
            {
                LogView.AppendText(text + Environment.NewLine);
                LogView.ScrollToEnd();
            });
        }
    }
}
