/// <summary>
/// DX.Comply.MapFile.Reader
/// Reads unit membership evidence from a detailed Delphi map file.
/// </summary>
///
/// <remarks>
/// The first implementation slice focuses on the most reliable signal in a
/// detailed Delphi map file: "Line numbers for <Unit>(<File>) ..." sections.
/// These entries prove that code from a unit participated in the linked result.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Comply.MapFile.Reader;

interface

uses
  System.RegularExpressions;

type
  /// <summary>
  /// Reads unit names from a detailed Delphi map file.
  /// </summary>
  TMapFileReader = class
  private
    /// <summary>
    /// Adds a unit name to the result only once, case-insensitively.
    /// </summary>
    class procedure AddUniqueUnitName(const AUnitName: string; var AUnitNames: TArray<string>); static;
    /// <summary>
    /// Tries to extract a unit name from a "Line numbers for" section header.
    /// </summary>
    class function TryExtractLineNumbersUnitName(const ARegEx: TRegEx; const ALine: string;
      out AUnitName: string): Boolean; static;
    /// <summary>
    /// Tries to extract a unit name from a "Detailed map of segments" entry (M=UnitName).
    /// </summary>
    class function TryExtractSegmentUnitName(const ARegEx: TRegEx; const ALine: string;
      out AUnitName: string): Boolean; static;
  public
    /// <summary>
    /// Reads unique unit names from the specified detailed map file.
    /// </summary>
    class function ReadUnitNames(const AMapFilePath: string): TArray<string>; static;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils;

const
  /// <summary>"Line numbers for &lt;Unit&gt;(&lt;File&gt;) ..." section header.</summary>
  cLineNumbersPattern = '^\s*Line numbers for\s+([A-Za-z0-9_\.]+)\s*\(';
  /// <summary>"Detailed map of segments" entry (M=UnitName).</summary>
  cSegmentPattern = '\bM=([A-Za-z0-9_\.]+)\b';

class procedure TMapFileReader.AddUniqueUnitName(const AUnitName: string;
  var AUnitNames: TArray<string>);
var
  LExistingUnitName: string;
begin
  if Trim(AUnitName) = '' then
    Exit;

  for LExistingUnitName in AUnitNames do
  begin
    if SameText(LExistingUnitName, AUnitName) then
      Exit;
  end;

  SetLength(AUnitNames, Length(AUnitNames) + 1);
  AUnitNames[High(AUnitNames)] := AUnitName;
end;

class function TMapFileReader.ReadUnitNames(const AMapFilePath: string): TArray<string>;
var
  LLine: string;
  LLineNumbersRegEx: TRegEx;
  LLines: TStringList;
  LSegmentRegEx: TRegEx;
  LUnitName: string;
begin
  Result := nil;
  if not TFile.Exists(AMapFilePath) then
    Exit;

  // Compiled once per file. The class function TRegEx.Match compiles its
  // pattern on every call, which made large map files take minutes.
  LLineNumbersRegEx := TRegEx.Create(cLineNumbersPattern, [roIgnoreCase, roCompiled]);
  LSegmentRegEx := TRegEx.Create(cSegmentPattern, [roCompiled]);

  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(AMapFilePath);
    for LLine in LLines do
    begin
      if TryExtractLineNumbersUnitName(LLineNumbersRegEx, LLine, LUnitName) then
      begin
        AddUniqueUnitName(LUnitName, Result);
      end
      else if TryExtractSegmentUnitName(LSegmentRegEx, LLine, LUnitName) then
      begin
        AddUniqueUnitName(LUnitName, Result);
      end;
    end;
  finally
    LLines.Free;
  end;
end;

class function TMapFileReader.TryExtractLineNumbersUnitName(const ARegEx: TRegEx;
  const ALine: string; out AUnitName: string): Boolean;
var
  LMatch: TMatch;
begin
  AUnitName := '';
  LMatch := ARegEx.Match(ALine);
  Result := LMatch.Success;
  if Result then
    AUnitName := Trim(LMatch.Groups[1].Value);
end;

class function TMapFileReader.TryExtractSegmentUnitName(const ARegEx: TRegEx;
  const ALine: string; out AUnitName: string): Boolean;
var
  LMatch: TMatch;
begin
  AUnitName := '';
  LMatch := ARegEx.Match(ALine);
  Result := LMatch.Success;
  if Result then
    AUnitName := Trim(LMatch.Groups[1].Value);
end;

end.