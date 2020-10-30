unit Json.Reflect.Enum;

interface

uses
  TypInfo, Jsons, Json.Reflect.Parser, Json.Reflect.TypeValue;

type
  TEnumStringTypeConverter = class(TCustomTypeConverter)
  public
    function Parse(const AValueType: PTypeInfo; const AValue: TTypedValue; const AArg: TObject = nil): TJsonValue; override;
  end;

  TEnumStringTypeReverter = class(TCustomTypeReverter)
  public
    function Parse(const AValueType: PTypeInfo; const AValue: TTypedValue; const AArg: TObject = nil): boolean; override;
  end;

implementation

{ TEnumStringTypeConverter }

function TEnumStringTypeConverter.Parse(const AValueType: PTypeInfo;
  const AValue: TTypedValue; const AArg: TObject): TJsonValue;
begin
  Result := TJsonValue.Create(nil);
  Result.AsString := AValue.AsString;
end;

{ TEnumStringTypeReverter }

function TEnumStringTypeReverter.Parse(const AValueType: PTypeInfo;
  const AValue: TTypedValue; const AArg: TObject): boolean;
begin
  AValue.AsString := TJsonValue(AArg).AsString;
  Result := true;
end;

end.
