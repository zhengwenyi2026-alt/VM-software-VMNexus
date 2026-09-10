using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;

namespace VMStart.UI.Controls
{
    public partial class SerialTerminalControl : UserControl, IDisposable
    {
        private TcpClient _client;
        private NetworkStream _stream;
        private Thread _worker;
        private volatile bool _running;
        private readonly List<string> _lines = new();
        private string _currentLine = "";
        private const int MaxLines = 5000;
        private readonly object _lock = new();

        public bool IsConnected { get; private set; }
        public event Action OnConnected;
        public event Action OnDisconnected;

        public SerialTerminalControl()
        {
            InitializeComponent();
            AppendLine("AirVM Serial Terminal");
            AppendLine("Waiting for connection...");
        }

        // ─── Connection ───

        public void Connect(string host = "127.0.0.1", int port = 4321)
        {
            Disconnect();
            _running = true;
            _worker = new Thread(() => Run(host, port))
            {
                Name = "SerialClient",
                IsBackground = true
            };
            _worker.Start();
        }

        public void Disconnect()
        {
            _running = false;
            IsConnected = false;
            try { _client?.Close(); } catch { }
            _client = null;
            _stream = null;
            _worker = null;
        }

        private void Run(string host, int port)
        {
            try
            {
                _client = new TcpClient();
                _client.Connect(host, port);
                _stream = _client.GetStream();

                IsConnected = true;
                Dispatcher.Invoke(() =>
                {
                    AppendLine($"[Connected to serial port {port}]");
                    OnConnected?.Invoke();
                });

                ReadLoop();
            }
            catch (Exception ex)
            {
                Dispatcher.Invoke(() => AppendLine($"[Error: {ex.Message}]"));
            }
            finally
            {
                IsConnected = false;
                Dispatcher.Invoke(() => OnDisconnected?.Invoke());
            }
        }

        private void ReadLoop()
        {
            var buf = new byte[4096];
            while (_running)
            {
                if (!_stream.DataAvailable)
                {
                    Thread.Sleep(10);
                    continue;
                }
                int n = _stream.Read(buf, 0, buf.Length);
                if (n <= 0) break;

                var str = Encoding.UTF8.GetString(buf, 0, n);
                ProcessANSI(str);
            }
        }

        // ─── ANSI Processing ───

        private void ProcessANSI(string text)
        {
            // Strip ANSI escape sequences
            var cleaned = Regex.Replace(text, @"\x1b\[[0-9;]*[a-zA-Z]", "");
            cleaned = Regex.Replace(cleaned, @"\x1b\([a-zA-Z]", "");

            Dispatcher.Invoke(() =>
            {
                foreach (char ch in cleaned)
                {
                    if (ch == '\r') continue;
                    if (ch == '\n')
                    {
                        FlushLine();
                    }
                    else if (ch == '\b')
                    {
                        if (_currentLine.Length > 0)
                            _currentLine = _currentLine[..^1];
                    }
                    else
                    {
                        _currentLine += ch;
                    }
                }
                RefreshDisplay();
            });
        }

        private void FlushLine()
        {
            lock (_lock)
            {
                _lines.Add(_currentLine);
                if (_lines.Count > MaxLines) _lines.RemoveRange(0, _lines.Count - MaxLines);
                _currentLine = "";
            }
        }

        private void AppendLine(string text)
        {
            lock (_lock)
            {
                _lines.Add(text);
                if (_lines.Count > MaxLines) _lines.RemoveRange(0, _lines.Count - MaxLines);
            }
            RefreshDisplay();
        }

        private void RefreshDisplay()
        {
            lock (_lock)
            {
                var allLines = new List<string>(_lines);
                if (!string.IsNullOrEmpty(_currentLine)) allLines.Add(_currentLine);
                TerminalOutput.Text = string.Join("\n", allLines);
            }
            TerminalOutput.ScrollToEnd();
        }

        // ─── Input ───

        private void InputBox_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Enter)
            {
                SendInput();
                e.Handled = true;
            }
        }

        private void SendInput()
        {
            var text = InputBox.Text;
            InputBox.Text = "";

            if (!IsConnected || _stream == null)
            {
                AppendLine("[Not connected]");
                return;
            }

            var data = Encoding.UTF8.GetBytes(text + "\r\n");
            try
            {
                _stream.Write(data, 0, data.Length);
            }
            catch
            {
                AppendLine("[Send failed]");
            }
        }

        public void SendString(string text)
        {
            if (!IsConnected || _stream == null) return;
            var data = Encoding.UTF8.GetBytes(text);
            try { _stream.Write(data, 0, data.Length); } catch { }
        }

        public void ClearScreen()
        {
            lock (_lock)
            {
                _lines.Clear();
                _currentLine = "";
            }
            Dispatcher.Invoke(() => RefreshDisplay());
        }

        public void Dispose()
        {
            Disconnect();
        }
    }
}
