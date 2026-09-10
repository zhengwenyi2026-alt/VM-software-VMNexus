using System;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace VMStart.UI.Controls
{
    /// <summary>
    /// VNC (RFB 3.8) client WPF control — connects to QEMU VNC server
    /// and renders the VM framebuffer using WriteableBitmap.
    /// </summary>
    public class VNCViewerControl : Control, IDisposable
    {
        private WriteableBitmap _bitmap;
        private readonly Image _image;
        private TcpClient _client;
        private NetworkStream _stream;
        private Thread _worker;
        private volatile bool _running;
        private int _fbWidth, _fbHeight;
        private int _bpp = 4;
        private bool _bigEndian;
        private uint _rShift, _gShift, _bShift;
        private uint _rMax, _gMax, _bMax;
        private byte _mouseMask;
        private readonly object _lock = new();

        public bool IsConnected { get; private set; }
        public int FramebufferWidth => _fbWidth;
        public int FramebufferHeight => _fbHeight;
        public event Action OnConnected;
        public event Action OnDisconnected;

        public VNCViewerControl()
        {
            Background = Brushes.Black;
            _image = new Image { Stretch = Stretch.Uniform };
            Focusable = true;

            // Use a Grid as the visual tree
            var grid = new Grid { Background = Brushes.Black };
            grid.Children.Add(_image);

            // We need to be a ContentControl or use AddVisualChild
            // Instead, use a simpler approach: override visual children
            _visualChild = grid;
            AddVisualChild(grid);
            AddLogicalChild(grid);
        }

        private readonly UIElement _visualChild;
        protected override int VisualChildrenCount => 1;
        protected override Visual GetVisualChild(int index) => (Visual)_visualChild;

        // ─── Connection ───

        public void Connect(string host = "127.0.0.1", int port = 5900)
        {
            Disconnect();
            _running = true;
            _worker = new Thread(() => Run(host, port))
            {
                Name = "VNCClient",
                IsBackground = true,
                Priority = ThreadPriority.Highest
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
            Dispatcher.Invoke(() => OnDisconnected?.Invoke());
        }

        private void Run(string host, int port)
        {
            try
            {
                _client = new TcpClient();
                _client.Connect(host, port);
                _stream = _client.GetStream();

                Handshake();
                ServerInit();

                IsConnected = true;
                Dispatcher.Invoke(() => OnConnected?.Invoke());

                FramebufferUpdateRequest(false);
                EventLoop();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"VNC error: {ex.Message}");
            }
            finally
            {
                IsConnected = false;
                Dispatcher.Invoke(() => OnDisconnected?.Invoke());
            }
        }

        // ─── RFB Handshake ───

        private void Handshake()
        {
            var ver = ReadBytes(12);
            var verStr = Encoding.ASCII.GetString(ver);
            if (!verStr.StartsWith("RFB "))
                throw new Exception("Invalid RFB protocol");

            WriteBytes(Encoding.ASCII.GetBytes("RFB 003.008\n"));

            int numTypes = ReadU8();
            if (numTypes == 0) throw new Exception("No security types");
            var types = ReadBytes(numTypes);

            if (!Array.Exists(types, t => t == 1))
                throw new Exception("No supported security type");
            WriteBytes(new byte[] { 1 }); // None

            uint result = ReadU32();
            if (result != 0) throw new Exception($"Security failed: {result}");
        }

        // ─── ServerInit ───

        private void ServerInit()
        {
            _fbWidth = ReadU16();
            _fbHeight = ReadU16();

            // Pixel format (16 bytes)
            var pf = ReadBytes(16);
            _bpp = pf[0] / 8;
            _bigEndian = pf[2] != 0;
            _rMax = (uint)(pf[4] << 8 | pf[5]);
            _gMax = (uint)(pf[6] << 8 | pf[7]);
            _bMax = (uint)(pf[8] << 8 | pf[9]);
            _rShift = pf[10];
            _gShift = pf[11];
            _bShift = pf[12];

            // Desktop name
            uint nameLen = ReadU32();
            if (nameLen > 0) ReadBytes((int)nameLen);

            // Create bitmap
            Dispatcher.Invoke(() =>
            {
                _bitmap = new WriteableBitmap(_fbWidth, _fbHeight, 96, 96, PixelFormats.Bgra32, null);
                _image.Source = _bitmap;
            });
        }

        // ─── Event Loop ───

        private void EventLoop()
        {
            while (_running)
            {
                if (!_stream.DataAvailable)
                {
                    Thread.Sleep(5);
                    continue;
                }

                byte msgType = ReadU8();
                switch (msgType)
                {
                    case 0: // FramebufferUpdate
                        HandleFBUpdate();
                        FramebufferUpdateRequest(true);
                        break;
                    case 2: // Bell
                        System.Media.SystemSounds.Beep.Play();
                        break;
                    case 3: // ServerCutText
                        HandleServerCutText();
                        break;
                }
            }
        }

        private void FramebufferUpdateRequest(bool incremental)
        {
            var m = new byte[] {
                3, (byte)(incremental ? 1 : 0),
                0, 0, 0, 0,
                (byte)(_fbWidth >> 8), (byte)(_fbWidth & 0xFF),
                (byte)(_fbHeight >> 8), (byte)(_fbHeight & 0xFF)
            };
            WriteBytes(m);
        }

        private void HandleFBUpdate()
        {
            ReadU8(); // padding
            int numRects = ReadU16();

            for (int i = 0; i < numRects; i++)
            {
                int x = ReadU16(), y = ReadU16();
                int w = ReadU16(), h = ReadU16();
                int enc = (int)ReadU32();

                switch (enc)
                {
                    case 0: // Raw
                        DecodeRaw(x, y, w, h);
                        break;
                    case -223: // DesktopSize
                        _fbWidth = w;
                        _fbHeight = h;
                        Dispatcher.Invoke(() =>
                        {
                            _bitmap = new WriteableBitmap(w, h, 96, 96, PixelFormats.Bgra32, null);
                            _image.Source = _bitmap;
                        });
                        break;
                    default:
                        // Skip unsupported encodings
                        break;
                }
            }
        }

        private void DecodeRaw(int x, int y, int w, int h)
        {
            int rowBytes = w * _bpp;
            byte[] rowBuf = new byte[rowBytes];

            for (int row = 0; row < h; row++)
            {
                ReadBytesInto(rowBuf, rowBytes);
                int dstY = y + row;
                if (dstY >= _fbHeight) continue;

                // Convert to BGRA32 and write to bitmap
                Dispatcher.Invoke(() =>
                {
                    if (_bitmap == null || dstY >= _bitmap.PixelHeight) return;
                    int[] pixels = new int[w];
                    for (int col = 0; col < w; col++)
                    {
                        int off = col * _bpp;
                        uint pixel = 0;
                        if (_bigEndian)
                        {
                            for (int b = 0; b < _bpp; b++)
                                pixel = (pixel << 8) | rowBuf[off + b];
                        }
                        else
                        {
                            for (int b = 0; b < _bpp; b++)
                                pixel |= (uint)rowBuf[off + b] << (b * 8);
                        }
                        uint r = ((pixel >> (int)_rShift) & _rMax) * 255 / Math.Max(_rMax, 1);
                        uint g = ((pixel >> (int)_gShift) & _gMax) * 255 / Math.Max(_gMax, 1);
                        uint bl = ((pixel >> (int)_bShift) & _bMax) * 255 / Math.Max(_bMax, 1);
                        // BGRA
                        pixels[col] = (int)(0xFF000000 | (r << 16) | (g << 8) | bl);
                    }
                    var rect = new Int32Rect(x, dstY, w, 1);
                    _bitmap.WritePixels(rect, pixels, w * 4, 0);
                }, DispatcherPriority.Render);
            }
        }

        private void HandleServerCutText()
        {
            ReadBytes(3); // padding
            uint len = ReadU32();
            var text = ReadBytes((int)len);
            var str = Encoding.UTF8.GetString(text);
            Dispatcher.Invoke(() =>
            {
                try { Clipboard.SetText(str); } catch { }
            });
        }

        // ─── Keyboard ───

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (!IsConnected) { base.OnKeyDown(e); return; }
            uint ks = WpfKeyToKeysym(e.Key);
            SendKeyEvent(ks, true);
            e.Handled = true;
        }

        protected override void OnKeyUp(KeyEventArgs e)
        {
            if (!IsConnected) return;
            uint ks = WpfKeyToKeysym(e.Key);
            SendKeyEvent(ks, false);
            e.Handled = true;
        }

        private void SendKeyEvent(uint keysym, bool down)
        {
            var m = new byte[] {
                4, (byte)(down ? 1 : 0), 0, 0,
                (byte)(keysym >> 24), (byte)((keysym >> 16) & 0xFF),
                (byte)((keysym >> 8) & 0xFF), (byte)(keysym & 0xFF)
            };
            WriteBytes(m);
        }

        private uint WpfKeyToKeysym(Key key) => key switch
        {
            Key.Return => 0xFF0D, Key.Tab => 0xFF09, Key.Back => 0xFF08,
            Key.Escape => 0xFF1B, Key.Delete => 0xFFFF,
            Key.Home => 0xFF50, Key.End => 0xFF57,
            Key.PageUp => 0xFF55, Key.PageDown => 0xFF56,
            Key.Left => 0xFF51, Key.Up => 0xFF52,
            Key.Right => 0xFF53, Key.Down => 0xFF54,
            Key.Insert => 0xFF63,
            Key.F1 => 0xFFBE, Key.F2 => 0xFFBF, Key.F3 => 0xFFC0,
            Key.F4 => 0xFFC1, Key.F5 => 0xFFC2, Key.F6 => 0xFFC3,
            Key.F7 => 0xFFC4, Key.F8 => 0xFFC5, Key.F9 => 0xFFC6,
            Key.F10 => 0xFFC7, Key.F11 => 0xFFC8, Key.F12 => 0xFFC9,
            Key.LeftShift or Key.RightShift => 0xFFE1,
            Key.LeftCtrl or Key.RightCtrl => 0xFFE3,
            Key.LeftAlt or Key.RightAlt => 0xFFE9,
            Key.LWin or Key.RWin => 0xFFEB,
            _ => KeyToChar(key)
        };

        private uint KeyToChar(Key key)
        {
            // Simple ASCII mapping for letter/number keys
            int v = KeyInterop.VirtualKeyFromKey(key);
            if (v >= 0x41 && v <= 0x5A) return (uint)v; // A-Z
            if (v >= 0x30 && v <= 0x39) return (uint)v; // 0-9
            if (v == 0x20) return 0x20; // Space
            return 0;
        }

        // ─── Mouse ───

        protected override void OnMouseDown(MouseButtonEventArgs e)
        {
            Focus();
            if (e.LeftButton == MouseButtonState.Pressed) _mouseMask |= 1;
            if (e.RightButton == MouseButtonState.Pressed) _mouseMask |= 4;
            if (e.MiddleButton == MouseButtonState.Pressed) _mouseMask |= 2;
            SendPointer(e);
        }

        protected override void OnMouseUp(MouseButtonEventArgs e)
        {
            if (e.LeftButton == MouseButtonState.Released) _mouseMask &= unchecked((byte)~1);
            if (e.RightButton == MouseButtonState.Released) _mouseMask &= unchecked((byte)~4);
            if (e.MiddleButton == MouseButtonState.Released) _mouseMask &= unchecked((byte)~2);
            SendPointer(e);
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (_mouseMask != 0) SendPointer(e);
        }

        protected override void OnMouseWheel(MouseWheelEventArgs e)
        {
            _mouseMask |= (byte)(e.Delta > 0 ? 8 : 16);
            SendPointer(e);
            _mouseMask &= (byte)~(8 | 16);
            SendPointer(e);
        }

        private void SendPointer(MouseEventArgs e)
        {
            if (_bitmap == null) return;
            var pos = e.GetPosition(_image);
            // Scale from image display size to framebuffer size
            double scaleX = _fbWidth / Math.Max(_image.ActualWidth, 1);
            double scaleY = _fbHeight / Math.Max(_image.ActualHeight, 1);
            int vx = Math.Clamp((int)(pos.X * scaleX), 0, _fbWidth - 1);
            int vy = Math.Clamp((int)(pos.Y * scaleY), 0, _fbHeight - 1);
            var m = new byte[] {
                5, _mouseMask,
                (byte)(vx >> 8), (byte)(vx & 0xFF),
                (byte)(vy >> 8), (byte)(vy & 0xFF)
            };
            WriteBytes(m);
        }

        // ─── Wire I/O ───

        private byte[] ReadBytes(int n)
        {
            var buf = new byte[n];
            ReadBytesInto(buf, n);
            return buf;
        }

        private void ReadBytesInto(byte[] buf, int n)
        {
            int got = 0;
            while (got < n)
            {
                int r = _stream.Read(buf, got, n - got);
                if (r <= 0) throw new IOException("Read failed");
                got += r;
            }
        }

        private byte ReadU8() => ReadBytes(1)[0];
        private int ReadU16()
        {
            var b = ReadBytes(2);
            return (b[0] << 8) | b[1];
        }
        private uint ReadU32()
        {
            var b = ReadBytes(4);
            return ((uint)b[0] << 24) | ((uint)b[1] << 16) | ((uint)b[2] << 8) | b[3];
        }

        private void WriteBytes(byte[] data)
        {
            _stream?.Write(data, 0, data.Length);
        }

        public void Dispose()
        {
            Disconnect();
            _bitmap = null;
        }
    }
}
