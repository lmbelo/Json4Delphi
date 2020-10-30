unit Json.Reflect.Date;

interface

uses
  TypInfo, Jsons, Json.Reflect.Parser, Json.Reflect.TypeValue;

type
  TYMDDateTime = TDateTime;
  PYMDDateTime = ^TYMDDateTime;

  TYMDDateTimeTypeConverter = class(TCustomTypeConverter)
  public
    function Parse(const AValueType: PTypeInfo; const AValue: TTypedValue; const AArg: TObject = nil): TJsonValue; override;
  end;

  TYMDDateTimeTypeReverter = class(TCustomTypeReverter)
  public
    function Parse(const AValueType: PTypeInfo; const AValue: TTypedValue; const AArg: TObject = nil): boolean; override;
  end;

implementation

uses
  SysUtils;

{ TYMDDateTimeTypeConverter }

function TYMDDateTimeTypeConverter.Parse(const AValueType: PTypeInfo;
  const AValue: TTypedValue; const AArg: TObject): TJsonValue;
begin
  Result := TJsonValue.Create(nil);
  Result.AsString := FormatDateTime('YYYY-MM-DD', AValue.AsDateTime);
end;

{ TYMDDateTimeTypeReverter }

function TYMDDateTimeTypeReverter.Parse(const AValueType: PTypeInfo;
  const AValue: TTypedValue; const AArg: TObject): Boolean;
var
  LFormatSettings: TFormatSettings;
begin
  LFormatSettings.DateSeparator := '-';
  LFormatSettings.ShortDateFormat := 'YYYY-MM-DD';
  LFormatSettings.TimeSeparator := ':';
  LFormatSettings.ShortTimeFormat := 'hh:mm';
  LFormatSettings.LongTimeFormat := 'hh:mm:ss';

  if (AValue.ValueType = TypeInfo(variant)) then begin
    AValue.AsVariant := StrToDateTime(TJsonValue(AArg).AsString, LFormatSettings);
  end else
    AValue.AsDateTime := StrToDateTime(TJsonValue(AArg).AsString, LFormatSettings);
  Result := true;   
end;

end.
