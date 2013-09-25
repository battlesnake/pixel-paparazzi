unit Bitmap;

interface

uses
  Windows;

procedure SaveBitmap(Bmp: HBITMAP; DC: HDC; {const} Filename: PChar {string});

implementation

function CreateBitmapInfoStruct(Bmp: HBITMAP): PBitmapInfo;
var
  ClrBits: Word;
  B: tagBITMAP;
begin
  GetObject(Bmp, sizeof(TBitmap), @B);

  ClrBits := B.bmPlanes * B.bmBitsPixel;
  if ClrBits = 1 then
    ClrBits := 1
  else if ClrBits <= 4 then
    ClrBits := 4
  else if ClrBits <= 8 then
    ClrBits := 8
  else if ClrBits <= 16 then
    ClrBits := 16
  else if ClrBits <= 24 then
    ClrBits := 24
  else
    ClrBits := 32;

  // Allocate memory for the BITMAPINFO structure. (This structure
  // contains a BITMAPINFOHEADER structure and an array of RGBQUAD
  // data structures.)
  if ClrBits < 24 then
    GetMem(Result, SizeOf(BITMAPINFOHEADER) + sizeof(RGBQUAD) * (1 shl ClrBits))
  else
    GetMem(Result, SizeOf(BITMAPINFOHEADER));

  Result.bmiHeader.biSize := sizeof(BITMAPINFOHEADER);
  Result.bmiHeader.biWidth := B.bmWidth;
  Result.bmiHeader.biHeight := B.bmHeight;
  Result.bmiHeader.biPlanes := B.bmPlanes;
  Result.bmiHeader.biBitCount := B.bmBitsPixel;
  if ClrBits < 24 then
    Result.bmiHeader.biClrUsed := 1 shl ClrBits;

  Result.bmiHeader.biCompression := BI_RGB;

  Result.bmiHeader.biSizeImage := (((Result.bmiHeader.biWidth * ClrBits + 31) and not 31) shr 3) * Result.bmiHeader.biHeight;
  Result.bmiHeader.biClrImportant := 0;
end;

procedure SaveBitmap(Bmp: HBITMAP; DC: HDC; {const} Filename: PChar {string});
var
  F: THandle;
  Info: PBitmapInfo;
  hdr: BITMAPFILEHEADER;
  bih: PBitmapInfoHeader;
  Bits: PByte;
  BitCount: Integer;
  Tmp: Cardinal;
begin
  { Get bitmap info }
  Info := CreateBitmapInfoStruct(Bmp);

  { Get address of bitmap header for better readability below }
  bih := @Info.bmiHeader;
  
  { Prepare image buffer }
  GetMem(Bits, bih.biSizeImage);

  { Get image }
  GetDIBits(DC, Bmp, 0, bih.biHeight, Bits, Info^, DIB_RGB_COLORS);

  { Prepare file header }
  hdr.bfType := $4d42;        // 0x42 = "B" 0x4d = "M"
  hdr.bfSize := sizeof(BITMAPFILEHEADER) + bih.biSize + bih.biClrUsed * SizeOf(RGBQUAD) + bih.biSizeImage;
  hdr.bfReserved1 := 0;
  hdr.bfReserved2 := 0;

  { Compute the palette offset }
  hdr.bfOffBits := SizeOf(BITMAPFILEHEADER) + bih.biSize + bih.biClrUsed * SizeOf(RGBQUAD);

  { Open file }
  F := CreateFile(PChar(Filename), GENERIC_READ or GENERIC_WRITE, 0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);

  { Write file header }
  WriteFile(F, hdr, SizeOf(BITMAPFILEHEADER), Tmp, nil);

  { Write image header and palette }
  WriteFile(F, bih^, SizeOf(BITMAPINFOHEADER) + bih.biClrUsed * SizeOf(RGBQUAD), Tmp, nil);

  { Write image }
  BitCount := bih.biSizeImage;
  WriteFile(F, Bits^, BitCount, Tmp, nil);

  { Clean up }
  FreeMem(Bits);
  CloseHandle(F);
end;

end.
