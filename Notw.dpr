{ PRINTSCR     take snapshot }
{ CTRL+BRK     close }
{ ALT+SCROLL   capture window under cursor }
program Notw;

uses
  Windows,
  Messages,
  ShellAPI,
  Bitmap in 'Bitmap.pas';

const
  WndClassName: PChar = 'NotwClass';
  WindowName: PChar = 'Battlesnake "News of the World"';
  TrayTip: string[63] = 'Snap = PrintScreen'#13#10'Subwindow = Alt+Scroll'#13#10'Quit = Ctrl+Break'#0;
  IconName: PChar = 'MAINICON';
  FilenameFmt: PChar = 'SGxxx_iii.bmp';

var
  Filename: PChar;
  Index: Integer;
  Source: HWND;

procedure IntToStr(S: PChar; Start: Integer; X: Integer; Digits: Byte);
begin
  Inc(S, Start + Digits);
  while Digits > 0 do begin
    S^ := Chr(Ord('0') + (X mod 10));
    Dec(S);
    X := X div 10;
    Dec(Digits);
  end; 
end;

procedure Snapshot;
var
  Scrn, Mem: HDC;
  Bmp, Old: HBITMAP;
  w, h: Integer;
  R: TRect;
begin
  { Get source DC }
  if Source = 0 then begin
    Scrn := CreateDC('DISPLAY', nil, nil, nil);
    w := GetDeviceCaps(Scrn, HORZRES);
    h := GetDeviceCaps(Scrn, VERTRES);
  end
  else begin
    Scrn := GetDC(Source);
    GetWindowRect(Source, R);
    w := R.Right - R.Left;
    h := R.Bottom - R.Top;
  end;
  { Create memory DC }
  Mem  := CreateCompatibleDC(Scrn);
  { Create bitmap and select into memory DC }
  Bmp := CreateCompatibleBitmap(Scrn, w, h);
  Old := SelectObject(Mem, Bmp);
  { Copy from screen DC to memory DC }
  BitBlt(Mem, 0, 0, w, h, Scrn, 0, 0, SRCCOPY);
  SelectObject(Mem, Old);
  { Save }
  Inc(Index);
  IntToStr(Filename, 5, Index, 3);
  SaveBitmap(Bmp, Mem, Filename);
  { Clean up }
  DeleteDC(Mem);
  DeleteDC(Scrn);
  DeleteObject(Bmp);
end;

procedure Close;
begin
  PostQuitMessage(0);
end;

procedure ProcessMessages;
var
  Msg: TMsg;
begin
  while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do
    DispatchMessage(Msg);
end;

procedure Capture(W: HWND);
var
  A: HWND;
  P: TPoint;
  R: TRect;
  I: Integer;
begin
  { Get window at cursor pos }
  GetCursorPos(P);
  A := WindowFromPoint(P);
  { Go up to desktop or child of previous selection }
  while (A <> Source) and (A <> 0) and (GetParent(A) <> Source) do
    A := GetParent(A);
  Source := A;
  { Get rect }
  GetWindowRect(A, R);
  Dec(R.Right, R.Left);
  Dec(R.Bottom, R.Top);
  { Move app window over target window (for flashing ) }
  MoveWindow(W, R.Left, R.Top, R.Right, R.Bottom, False);
  { Flash window twice }
  for I := 1 to 2 do begin
    { Show window }
    ShowWindow(W, SW_SHOW);
    BringWindowToTop(W);
    { Process messages }
    ProcessMessages;
    Sleep(20);
    { Hide window }
    ShowWindow(W, SW_HIDE);
    { Process messages }
    ProcessMessages;
    Sleep(70);
  end;
end;

{$R *.res}

var {static} NI: NotifyIconData = (uID: 1; uFlags: NIF_MESSAGE or NIF_ICON or NIF_TIP; uCallbackMessage: WM_USER);
function WndProc(W: HWND; Msg: Cardinal; wParam, lParam: Integer): Integer; stdcall;
begin
  case Msg of
    WM_CREATE: begin
      { Filename }
      GetMem(Filename, Length(FilenameFmt)+1);
      Move(FilenameFmt^, Filename^, Length(FilenameFmt)+1);
      IntToStr(Filename, 1, GetTickCount div 10, 3);
      { Hotkeys }
      RegisterHotKey(W, 101, 0, VK_SNAPSHOT);
      RegisterHotKey(W, 102, MOD_CONTROL, VK_CANCEL);
      RegisterHotKey(W, 103, MOD_ALT, VK_SCROLL);
      { Tray icon }
      NI.cbSize := SizeOf(NI);
      NI.Wnd := W;
      NI.hIcon := LoadIcon(HInstance, IconName);
      Move(TrayTip[1], NI.szTip, 64);
      Shell_NotifyIcon(NIM_ADD, @NI);
      MessageBox(W, PChar(@TrayTip[1]), WindowName, MB_OK);
    end;
    WM_DESTROY: begin
      { File name }
      FreeMem(Filename);
      { Hotkeys }
      UnregisterHotKey(W, 101);
      UnregisterHotKey(W, 102);
      UnregisterHotKey(W, 103);
      { Tray icon }
      Shell_NotifyIcon(NIM_DELETE, @NI);
    end;
    WM_CLOSE:
      PostQuitMessage(0);
    WM_HOTKEY:
      case wParam of
        101: Snapshot;
        102: Close;
        103: Capture(W);
      end;
    WM_USER:
      {case wParam of
        1:}
        case lParam of
          WM_LBUTTONDOWN: Snapshot;
          WM_RBUTTONDOWN: Close;
        end;
      {end;}
  end;
  Result := DefWindowProc(W, Msg, wParam, lParam);
end;

procedure MainBlock;
var
  Msg: TMsg;
  WC: WNDCLASS;
  W: HWND;
begin
  { Register window class }
  asm XOR EAX, EAX; MOV ECX, 10; LEA EDI, WC; REP STOSD; end;
  WC.lpfnWndProc := @WndProc;
  WC.hInstance := HINSTANCE;
  WC.hIcon := LoadIcon(HInstance, IconName);
  WC.hbrBackground := GetStockObject(BLACK_BRUSH);
  WC.lpszClassName := WndClassName;
  RegisterClass(WC);
  { Create window }
  W := CreateWindowEx(WS_EX_TOPMOST, WC.lpszClassName, WindowName, 0, 0, 0, 0, 0, 0, 0, HInstance, nil);
  { Remove border }
  SetWindowLong(W, GWL_STYLE, 0);
  { Message loop }
  while GetMessage(Msg, 0, 0, 0) do
    DispatchMessage(Msg);
  { Clean up }
  DestroyWindow(W);
  UnregisterClass(WC.lpszClassName, HInstance);
end;

begin
  MainBlock;
end.
