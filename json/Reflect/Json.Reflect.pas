unit Json.Reflect;

interface

uses
  Contnrs, TypInfo, Jsons, JsonsUtilsEx, Classes, Json.Reflect.Intf, Json.Reflect.TypeInfo, Json.Reflect.Parser,
  Json.Reflect.TypeValue;

type
  TJsonConverter = class(TInterfacedPersistent, IJsonConverter)
  private
    FConverters: TObjectList;
    function GetConverters(): TObjectList;
  protected
    function GetConverter(const AValueType: PTypeInfo; const APropName: string; const AAbsolute: boolean = true): TTypeConverterInfo;

    function ConvertObjectValuePropToJson(const AInstance: TObject; const AValueType: PTypeInfo; const AName: string; const AValue: TTypedValue): TJsonValue;
    function ConvertObjectSetPropToJson(const AInstance: TObject; const AValueType: PTypeInfo; const AName: string; const AValue: TTypedValue): TJsonValue;
    function ConvertObjectArrayPropToJson(const AInstance: TObject; const AValueType: PTypeInfo; const AName: string; const AValue: TTypedValue): TJsonValue;
    function ConvertObjectClassPropToJson(const AInstance: TObject; const AValueType: PTypeInfo; const AName: string; const AValue: TTypedValue): TJsonValue;
    function ConvertObjectToJson(const AValueType: PTypeInfo; const AValue: TTypedValue): TJsonValue;
    function ConvertArrayToJson(const AValueType: PTypeInfo; const AValue: TTypedValue): TJsonValue;
    function ConvertValueToJson(const AValueType: PTypeInfo; const AValue: TTypedValue): TJsonValue;
  public
    constructor Create();
    destructor Destroy(); override;

    function ConvertToJson(const AValueType: PTypeInfo; const AValue: TTypedValue): TJsonValue; overload;
  public
    //Proxy method
    procedure RegisterConverter(const AValueType: PTypeInfo; const AValueName: string; const ATypeConverter: TCustomTypeConverter); overload;
  public
    property Converters: TObjectList read GetConverters;
  end;

  TJsonMarshal = class
  private
    class function GetDefault: TJsonMarshal; static;
    class var FDefault: TJsonMarshal;
  private
    FConverter: TJsonConverter;
  public
    constructor Create(const AConverter: TJsonConverter);
    destructor Destroy(); override;

    function Marshal(const AValueType: PTypeInfo; const AValue): TJsonValue; overload;
    function Marshal(const AInstance: TObject): TJsonValue; overload;

    procedure RegisterConverter(const AValueType: PTypeInfo; const ATypeConverter: TCustomTypeConverter); overload;
    procedure RegisterConverter(const AClass: TClass; const APropName: string; const ATypeConverter: TCustomTypeConverter); overload;
  public
    class property Default: TJsonMarshal read GetDefault;
  end;

  TJsonReverter = class(TInterfacedPersistent, IJsonReverter)
  private
    FReverters: TObjectList;
    function GetReverters(): TObjectList;
  protected
    function GetReverter(const AValueType: PTypeInfo; const APropName: string; const AAbsolute: boolean = true): TTypeReverterInfo;

    procedure RevertJsonToObjectValueProp(const AJson: TJsonValue; const AInstance: TObject; const AValueType: PTypeInfo; const AName: string; const AValue: TTypedValue);
    procedure RevertJsonToObjectSetProp(const AJson: TJsonValue; const AInstance: TObject; const AValueType: PTypeInfo; const AName: string; const AValue: TTypedValue);
    procedure RevertJsonToObjectClassProp(const AJson: TJsonValue; const AInstance: TObject; const AValueType: PTypeInfo; const AName: string; const AValue: TTypedValue);
    procedure RevertJsonToObjectArrayProp(const AJson: TJsonValue; const AInstance: TObject; const AValueType: PTypeInfo; const AName: string; const AValue: TTypedValue);
    procedure RevertJsonToObject(const AJson: TJsonObject; const AValueType: PTypeInfo; const AValue: TTypedValue);
    procedure RevertJsonToArray(const AJson: TJsonArray; const AValueType: PTypeInfo; const AValue: TTypedValue);
    procedure RevertJsonToValue(const AJson: TJsonValue; const AValueType: PTypeInfo; const AValue: TTypedValue);
  public
    constructor Create();
    destructor Destroy(); override;

    procedure RevertFromJson(const AJson: TJsonValue; const AValueType: PTypeInfo; const AValue: TTypedValue);
  public
    //Proxy method
    procedure RegisterReverter(const AValueType: PTypeInfo; const AValueName: string; const ATypeReverter: TCustomTypeReverter); overload;
  public
    property Reverters: TObjectList read GetReverters;
  end;

  TJsonUnMarshal = class
  private
    class function GetDefault: TJsonUnMarshal; static;
    class var FDefault: TJsonUnMarshal;
  private
    FReverter: TJsonReverter;
  public
    constructor Create(const AReverter: TJsonReverter);
    destructor Destroy(); override;

    procedure UnMarshal(const AJson: string; const AValueType: PTypeInfo; var AValue); overload;
    procedure UnMarshal(const AJson: string; var AInstance: TObject); overload;

    procedure UnMarshal(const AJson: TJsonValue; const AValueType: PTypeInfo; var AValue); overload;
    procedure UnMarshal(const AJson: TJsonValue; var AInstance: TObject); overload;

    procedure RegisterReverter(const AValueType: PTypeInfo; const ATypeReverter: TCustomTypeReverter); overload;
    procedure RegisterReverter(const AClass: TClass; const APropName: string; const ATypeReverter: TCustomTypeReverter); overload;
  public
    class property Default: TJsonUnMarshal read GetDefault;
  end;

implementation

uses
  SysUtils, Variants, DateUtils, Json.Reflect.Exception, Json.Reflect.TypeCreator;

type
  TObjectDynArray = array of TObject;
  TStringDynArray = array of string;
  TIntegerDynArray = array of Integer;

  PObjectDynArray = ^TObjectDynArray;
  PStringDynArray = ^TStringDynArray;
  PIntegerDynArray = ^TIntegerDynArray;

  PPPTypeInfo = ^PPTypeInfo;

  TDataTypeManager = class
  private
    class function GetVarTypeSize(const AVarType : TVarType; var AIsArray : boolean): integer; static;
    class function GetValTypeSize(const ATypeInfo: PTypeInfo): integer; static;
  public
    class procedure NewMem(const ATypeInfo: PTypeInfo; var ADest: Pointer); static;
    class procedure DispMem(const ASource: variant; var AValue: Pointer); overload; static;
    class procedure DispMem(const ATypeInfo: PTypeInfo; var AValue: Pointer); overload; static;
    class procedure CopyVar(const ASource: variant; var ADest); overload; static;
    class procedure CopyVar(const ASource: variant; var ADest: pointer; const ANewNem: boolean = true); overload; static;
    class procedure CopyVal(const ATypeInfo: PTypeInfo; const ASource: variant; var ADest: pointer; const ANewNem: boolean = true); overload; static;
    class function ParseValToVar(const ATypeInfo: PTypeInfo; const ASource): variant; static;
  end;

function ZeroFillStr(const ANumber, ASize : integer) : String;
begin
  Result := IntToStr(ANumber);
  while length(Result) < ASize do
    Result := '0' + Result;
end;

function JSONDateToString(const ADate : TDateTime) : String;
begin
  Result := '"' +
            ZeroFillStr(YearOf(ADate),4) +
            '-' +
            ZeroFillStr(MonthOf(ADate),2) +
            '-' +
            ZeroFillStr(DayOf(ADate),2) +
            'T' +
            ZeroFillStr(HourOf(ADate),2) +
            ':' +
            ZeroFillStr(MinuteOf(ADate),2) +
            ':' +
            ZeroFillStr(SecondOf(ADate),2) +
            '.' +
            ZeroFillStr(SecondOf(ADate),3) +
            'Z"';
end;

function JSONStringToDate(const ADate : String) : TDateTime;
begin
  Result := EncodeDateTime(
    StrToInt(Copy(ADate,2,4)),
    StrToInt(Copy(ADate,7,2)),
    StrToInt(Copy(ADate,10,2)),
    StrToInt(Copy(ADate,13,2)),
    StrToInt(Copy(ADate,16,2)),
    StrToInt(Copy(ADate,19,2)),
    StrToInt(Copy(ADate,22,3)));
end;

{ TJsonConverter }

constructor TJsonConverter.Create;
begin
  FConverters := TObjectList.Create(true);
end;

destructor TJsonConverter.Destroy;
begin
  FConverters.Free();
  inherited;
end;

function TJsonConverter.GetConverter(const AValueType: PTypeInfo;
  const APropName: string; const AAbsolute: boolean): TTypeConverterInfo;
var
  I: Integer;
  LConverter: TTypeConverterInfo;
begin
  Result := nil;
  for I := 0 to FConverters.Count - 1 do begin
    if (FConverters[I] is TTypeConverterInfo) then begin
      LConverter := TTypeConverterInfo(FConverters[I]);
      if not AAbsolute and (AValueType.Kind = tkClass) and (LConverter.ValueType^.Kind = tkClass) then begin
        if GetTypeData(AValueType)^.ClassType.InheritsFrom(GetTypeData(LConverter.ValueType)^.ClassType) and (LConverter.ValueName = APropName) then begin
          Result := LConverter;
          Break;
        end;
      end else if (LConverter.ValueType = AValueType) and (LConverter.ValueName = APropName) then begin
        Result := LConverter;
        Break;
      end;
    end;
  end;
  if not Assigned(Result) and AAbsolute and (AValueType.Kind = tkClass) then begin
    Result := GetConverter(AValueType, APropName, false);
  end;
end;

function TJsonConverter.GetConverters: TObjectList;
begin
  Result := FConverters;
end;

procedure TJsonConverter.RegisterConverter(const AValueType: PTypeInfo;
  const AValueName: string; const ATypeConverter: TCustomTypeConverter);
begin
  ATypeConverter.Converter := Self;
  Converters.Add(
    TTypeConverterInfo.Create(
      AValueType,
      AValueName,
      ATypeConverter
    )
  );
end;

function TJsonConverter.ConvertObjectClassPropToJson(const AInstance: TObject;
  const AValueType: PTypeInfo; const AName: string; const AValue: TTypedValue): TJsonValue;
var
  LConverter: TTypeConverterInfo;
begin
  LConverter := GetConverter(AInstance.ClassInfo, AName);
  if Assigned(LConverter) then begin
    Result := LConverter.TypeConverter.Parse(AValueType, AValue);
  end else begin
    Result := ConvertToJson(AValueType, AValue);
  end;
end;

function TJsonConverter.ConvertObjectSetPropToJson(const AInstance: TObject;
  const AValueType: PTypeInfo; const AName: string; const AValue: TTypedValue): TJsonValue;
var
  LConverter: TTypeConverterInfo;
begin
  LConverter := GetConverter(AInstance.ClassInfo, AName);
  if Assigned(LConverter) then begin
    Result := LConverter.TypeConverter.Parse(AValueType, AValue);
  end else
    Result := ConvertToJson(AValueType, AValue);
end;

function TJsonConverter.ConvertToJson(const AValueType: PTypeInfo;
  const AValue: TTypedValue): TJsonValue;
var
  LConverter: TTypeConverterInfo;
begin  
  LConverter := GetConverter(AValueType, EmptyStr);
  if Assigned(LConverter) then begin
    Result := LConverter.TypeConverter.Parse(AValueType, AValue);
    Exit;
  end;

  case AValueType^.Kind of
    tkInteger, tkFloat, tkInt64, tkChar, {$IFDEF FPC} tkAString, {$ENDIF} tkLString, tkString, tkWChar, tkWString, tkEnumeration: begin
      Result := ConvertValueToJson(AValueType, AValue);
    end;
    tkClass: begin
      Result := ConvertObjectToJson(AValueType, AValue);
    end;
    tkDynArray: begin
      Result := ConvertArrayToJson(AValueType, AValue);
    end;
    else raise Exception.Create('Type must be implemented');
  end;
end;

function TJsonConverter.ConvertValueToJson(const AValueType: PTypeInfo;
  const AValue: TTypedValue): TJsonValue;
var
  LTypeData: PTypeData;
  LJsonArray: TJsonArray;
  LPTypeInfo: PTypeInfo;
  I: Integer;
begin
  case AValueType^.Kind of
    tkInteger: begin
      Result := TJsonValue.Create(nil);
      TJsonValue(Result).AsInteger := AValue.AsInteger;
    end;
    tkFloat:
    begin
      Result := TJsonValue.Create(nil);
      if AValueType^.Name = 'TDateTime' then begin
        TJsonValue(Result).AsString := JSONDateToString(AValue.AsDateTime);
      end else if AValueType^.Name = 'TDate' then begin
        TJsonValue(Result).AsString := JSONDateToString(AValue.AsDateTime);
      end else if AValueType^.Name = 'TTime' then begin
        TJsonValue(Result).AsString := JSONDateToString(AValue.AsDateTime);
      end else if AValueType^.Name = 'Double' then begin
        TJsonValue(Result).AsNumber := AValue.AsDouble;
      end else begin
        TJsonValue(Result).AsNumber := AValue.AsExtended;
      end;
    end;
    tkInt64: begin
      Result := TJsonValue.Create(nil);
      TJsonValue(Result).AsNumber := AValue.AsInt64;
    end;
    tkChar: begin
      Result := TJsonValue.Create(nil);
      TJsonValue(Result).AsString := AValue.AsChar;
    end;
    {$IFDEF FPC}
    tkAString,
    {$ENDIF}
    tkLString,
    tkString: begin
      Result := TJsonValue.Create(nil);
      TJsonValue(Result).AsString := AValue.AsString;
    end;
    tkWChar: begin
      Result := TJsonValue.Create(nil);
      TJsonValue(Result).AsString := AValue.AsWideChar;
    end;
    tkWString: begin
      Result := TJsonValue.Create(nil);
      TJsonValue(Result).AsString := AValue.AsWideString;
    end;
    tkEnumeration:
    begin
      if (AValueType^.Name = 'Boolean') then begin
        Result := TJsonValue.Create(nil);
        TJsonValue(Result).AsBoolean := AValue.AsBoolean;
      end else begin
        Result := TJsonValue.Create(nil);
        Result.AsInteger := AValue.AsInteger;
      end;
    end;
    tkSet: begin
      LJsonArray := TJsonArray.Create(nil);
      LTypeData := GetTypeData(AValueType);
      LPTypeInfo := LTypeData.CompType^;
      for I := 0 to SizeOf(Integer) * 8 - 1 do
        if I in AValue.AsSet then begin
          LJsonArray.Put(GetEnumName(LPTypeInfo, I));
        end;
      Result := TJsonValue.Create(nil);
      try
        Result.AsArray := LJsonArray;
      finally
        LJsonArray.Free();
      end;
    end;
    else raise Exception.Create('Type must be implemented');
  end;
end;

function TJsonConverter.ConvertObjectValuePropToJson(const AInstance: TObject;
  const AValueType: PTypeInfo; const AName: string; const AValue: TTypedValue): TJsonValue;
var
  LConverter: TTypeConverterInfo;
begin
  LConverter := GetConverter(AInstance.ClassInfo, AName);
  if Assigned(LConverter) then begin
    Result := LConverter.TypeConverter.Parse(AValueType, AValue);
  end else
    Result := ConvertToJson(AValueType, AValue);
end;

function TJsonConverter.ConvertArrayToJson(const AValueType: PTypeInfo;
  const AValue: TTypedValue): TJsonValue;
var
  LTypeData: PTypeData;
  LPPPTypeInfo: PPPTypeInfo;
  LPPTypeInfo: PPTypeInfo;
  LJsonArray: TJsonArray;
  LArrStr: TStringDynArray;
  J: Integer;
  LArrInt: TIntegerDynArray;
  LArrObj: TObjectDynArray;
  LObjectValue: TObject;
  LJsonValue: TJsonObject;
  LValue: TTypedValue;
begin
  LJsonArray := TJsonArray.Create(nil);
  
  LTypeData := GetTypeData(AValueType);
  {$IFNDEF FPC}
  if not Assigned(LTypeData^.ElType2) then begin
    LPPPTypeInfo := PPPTypeInfo(lTypeData^.BaseType);
    LPPTypeInfo := LPPPTypeInfo^;
  end else begin
    LPPTypeInfo := lTypeData^.ElType2;
  end;
  case LPPTypeInfo^.Kind of
  {$ELSE}
  lTypeInfoFPC := lTypeData^.ElType2;
  case lTypeInfoFPC^.Kind of
    tkAString,
  {$ENDIF}
    tkString, tkLString: begin
      LArrStr := TStringDynArray(AValue.Raw^);
      for J := 0 to Length(LArrStr) -1 do begin
        LJsonArray.Put(LArrStr[J]);
      end;
      Result := TJsonValue.Create(nil);
      try
        Result.AsArray := LJsonArray;
      finally
        LJsonArray.Free();
      end;
    end;
    tkInteger : begin
      LArrInt := TIntegerDynArray(AValue.Raw^);
      for J := 0 to Length(LArrInt) -1 do begin
        LJsonArray.Put(LArrInt[J]);
      end;
      Result := TJsonValue.Create(nil);
      try
        Result.AsArray := LJsonArray;
      finally
        LJsonArray.Free();
      end;
    end;
    tkClass : begin
      LArrObj := TObjectDynArray(AValue.Raw^);
      for J := 0 to Length(LArrObj) -1 do begin
        LValue := TTypedValue.Create(LObjectValue.ClassInfo, LObjectValue);
        try
          LObjectValue := LArrObj[J];
          LJsonValue := TJsonObject(ConvertObjectToJson(LObjectValue.ClassInfo, LValue));
          try
            LJsonArray.Put(LJsonValue);
          finally
            LJsonValue.Free();
          end;
        finally
          LValue.Free();
        end;
      end;
      Result := TJsonValue.Create(nil);
      try
        Result.AsArray := LJsonArray;
      finally
        LJsonArray.Free();
      end;
    end else raise Exception.Create('Type must be implemented');
  end;
end;

function TJsonConverter.ConvertObjectArrayPropToJson(const AInstance: TObject;
  const AValueType: PTypeInfo; const AName: string; const AValue: TTypedValue): TJsonValue;
var
  LConverter: TTypeConverterInfo;
begin
  LConverter := GetConverter(AInstance.ClassInfo, AName);
  if Assigned(LConverter) then begin
    Result := LConverter.TypeConverter.Parse(AValueType, AValue);
  end else
    Result := ConvertToJson(AValueType, AValue);
end;

function TJsonConverter.ConvertObjectToJson(const AValueType: PTypeInfo;
  const AValue: TTypedValue): TJsonValue;

  procedure AddToResult(const AResult: TJsonObject; const APropName: string;
    const AJsonValue: TJsonValue; const AFreeInstance: boolean = true);
  begin
    if Assigned(AJsonValue) then begin
      if not (AJsonValue.ValueType in [jvArray, jvObject]) then
        AResult.Put(APropName, AJsonValue)
      else if AJsonValue.ValueType = jvObject then
        AResult.Put(APropName, AJsonValue.AsObject)
      else if AJsonValue.ValueType = jvArray then
        AResult.Put(APropName, AJsonValue.AsArray)
      else
        raise Exception.CreateFmt('Type %s must be implemented', [AJsonValue.ClassName]);
      if AFreeInstance then AJsonValue.Free();
    end;
  end;

var
  LPropList: PPropList;
  LPropCount: Integer;
  I: Integer;
  LObjectValue: TObject;
  LDynArrayValue: Pointer;
  LSetValue: Integer;
  LObject: TObject;
  LSource: Variant;
  LJsonObject: TJsonObject;
  LValue: TTypedValue;
  LDest: Pointer;
begin  
  LObject := AValue.AsObject;
  if (not Assigned(LObject)) or (LObject.ClassInfo = nil) then begin
    Result := TJsonValue.Create(nil);
    TJsonValue(Result).IsNull := true;
    Exit;
  end;

  Result := TJsonValue.Create(nil);
  LJsonObject := TJsonObject.Create();
  try
    LPropCount := GetPropList(AValueType, LPropList);
    for I := 0 to LPropCount - 1 do begin
      case LPropList[i]^.PropType^.Kind of
        tkInteger, tkInt64, tkFloat, tkChar, tkWChar, {$IFDEF FPC} tkAString, {$ENDIF} tkLString, tkString, tkWString, tkEnumeration: begin
          LSource := GetPropValue(LObject, LPropList[i]);
          TDataTypeManager.CopyVal(LPropList[I]^.PropType^, LSource, LDest);
          try
            LValue := TTypedValue.Create(LPropList[i]^.PropType^, LDest^);
            try
              AddToResult(LJsonObject, LPropList[i]^.Name,
                ConvertObjectValuePropToJson(LObject, LPropList[I]^.PropType^, LPropList[i]^.Name, LValue));
            finally
              LValue.Free();
            end;
          finally
            TDataTypeManager.DispMem(LSource, LDest);
          end;
        end;
        tkClass: begin
          LObjectValue := GetObjectProp(LObject, LPropList[i]);
          LValue := TTypedValue.Create(LPropList[i]^.PropType^, LObjectValue);
          try
            AddToResult(LJsonObject, LPropList[i]^.Name,
              ConvertObjectClassPropToJson(LObject, LPropList[I]^.PropType^, LPropList[i]^.Name, LValue));
          finally
            LValue.Free();
          end;
        end;
        tkDynArray: begin
          LDynArrayValue := GetDynArrayProp(LObject, LPropList[i]);
          LValue := TTypedValue.Create(LPropList[i]^.PropType^, LDynArrayValue);
          try
            AddToResult(LJsonObject, LPropList[i]^.Name,
            ConvertObjectArrayPropToJson(LObject, LPropList[I]^.PropType^, LPropList[i]^.Name, LValue));
          finally
            LValue.Free();
          end;
        end;
        tkSet: begin
          LSetValue := GetOrdProp(LObject, LPropList[i]);
          LValue := TTypedValue.Create(LPropList[i]^.PropType^, LSetValue);
          try
            AddToResult(LJsonObject, LPropList[i]^.Name,
              ConvertObjectSetPropToJson(LObject, LPropList[I]^.PropType^, LPropList[i]^.Name, LValue));
          finally
            LValue.Free();
          end;
        end;
        else raise Exception.Create('Type must be implemented');
      end;
    end;
    Result.AsObject := LJsonObject;
  finally
    LJsonObject.Free();
  end;
end;

{ TJsonMarshal }

constructor TJsonMarshal.Create(const AConverter: TJsonConverter);
begin
  FConverter := AConverter;
end;

destructor TJsonMarshal.Destroy;
begin
  FConverter.Free();
  inherited;
end;

class function TJsonMarshal.GetDefault: TJsonMarshal;
begin
  if not Assigned(FDefault) then
    FDefault := TJsonMarshal.Create(TJsonConverter.Create());
  Result := FDefault;
end;

function TJsonMarshal.Marshal(const AValueType: PTypeInfo;
  const AValue): TJsonValue;
var
  LValue: TTypedValue;
begin
  LValue := TTypedValue.Create(AValueType, AValue);
  try
    Result := FConverter.ConvertToJson(AValueType, LValue);
  finally
    LValue.Free();
  end;
end;

function TJsonMarshal.Marshal(const AInstance: TObject): TJsonValue;
begin
  Result := Marshal(AInstance.ClassInfo, AInstance);
end;

procedure TJsonMarshal.RegisterConverter(const AValueType: PTypeInfo;
  const ATypeConverter: TCustomTypeConverter);
begin
  FConverter.RegisterConverter(AValueType, EmptyStr, ATypeConverter);
end;

procedure TJsonMarshal.RegisterConverter(const AClass: TClass;
  const APropName: string; const ATypeConverter: TCustomTypeConverter);
begin
  FConverter.RegisterConverter(AClass.ClassInfo, APropName, ATypeConverter);
end;

{ TJsonReverter }

constructor TJsonReverter.Create;
begin
  FReverters := TObjectList.Create(true);
end;

destructor TJsonReverter.Destroy;
begin
  FReverters.Free();
  inherited;
end;

function TJsonReverter.GetReverter(const AValueType: PTypeInfo;
  const APropName: string; const AAbsolute: boolean): TTypeReverterInfo;
var
  I: Integer;
  LReverter: TTypeReverterInfo;
begin
  Result := nil;
  for I := 0 to FReverters.Count - 1 do begin
    if (FReverters[I] is TTypeReverterInfo) then begin
      LReverter := TTypeReverterInfo(FReverters[I]);
      if not AAbsolute and (AValueType.Kind = tkClass) and (LReverter.ValueType^.Kind = tkClass) then begin
        if GetTypeData(AValueType)^.ClassType.InheritsFrom(GetTypeData(LReverter.ValueType)^.ClassType) and (LReverter.ValueName = APropName) then begin
          Result := LReverter;
          Break;
        end;
      end else if (LReverter.ValueType = AValueType) and (LReverter.ValueName = APropName) then begin
        Result := LReverter;
        Break;
      end;
    end;
  end;
  if not Assigned(Result) and AAbsolute and (AValueType.Kind = tkClass) then begin
    Result := GetReverter(AValueType, APropName, false);
  end;
end;

function TJsonReverter.GetReverters: TObjectList;
begin
  Result := FReverters;
end;

procedure TJsonReverter.RegisterReverter(const AValueType: PTypeInfo;
  const AValueName: string; const ATypeReverter: TCustomTypeReverter);
begin
  ATypeReverter.Reverter := Self;
  Reverters.Add(
    TTypeReverterInfo.Create(
      AValueType,
      AValueName,
      ATypeReverter
    )
  );
end;

procedure TJsonReverter.RevertFromJson(const AJson: TJsonValue;
  const AValueType: PTypeInfo; const AValue: TTypedValue);
var
  LReverter: TTypeReverterInfo;
begin
  LReverter := GetReverter(AValueType, EmptyStr);
  if Assigned(LReverter) then begin
    if LReverter.TypeReverter.Parse(AValueType, AValue, AJson) then
      Exit;
  end;

  case AValueType^.Kind of
    tkInteger, tkFloat, tkInt64, tkChar, {$IFDEF FPC} tkAString, {$ENDIF} tkLString, tkString, tkWChar, tkWString, tkEnumeration: begin
      RevertJsonToValue(AJson, AValueType, AValue);
    end;
    tkClass: begin
      if (AJson.ValueType = jvObject) then
        RevertJsonToObject(AJson.AsObject, AValueType, AValue);
    end;
    tkDynArray: begin
      if (AJson.ValueType = jvArray) then
        RevertJsonToArray(AJson.AsArray, AValueType, AValue);
    end;
    else raise Exception.Create('Type must be implemented');
  end;
end;

procedure TJsonReverter.RevertJsonToArray(const AJson: TJsonArray;
  const AValueType: PTypeInfo; const AValue: TTypedValue);
var
  LTypeData: PTypeData;
  LPPPTypeInfo: PPPTypeInfo;
  LPPTypeInfo: PPTypeInfo;
  LPArrStr: PStringDynArray;
  I: Integer;
  LPArrInt: PIntegerDynArray;
  LPArrObj: PObjectDynArray;
begin
  LTypeData := GetTypeData(AValueType);
  {$IFNDEF FPC}
  if not Assigned(LTypeData^.ElType2) then begin
    LPPPTypeInfo := PPPTypeInfo(lTypeData^.BaseType);
    LPPTypeInfo := LPPPTypeInfo^;
  end else begin
    LPPTypeInfo := lTypeData^.ElType2;
  end;
  case LPPTypeInfo^.Kind of
    {$ELSE}
    LTypeInfoFPC := lTypeData^.ElType2;
    case lTypeInfoFPC^.Kind of
      tkAString,
    {$ENDIF}
      tkString, tkLString: begin
        LPArrStr := PStringDynArray(AValue.Raw^);
        SetLength(LPArrStr^, AJson.Count);
        for I := 0 to AJson.Count - 1 do begin
          if (AJson.Items[I].ValueType = jvString) then
            LPArrStr^[I] := AJson.Items[I].AsString;
        end;
      end;
      tkInteger : begin
        LPArrInt := PIntegerDynArray(AValue.Raw^);
        SetLength(LPArrInt^, AJson.Count);
        for I := 0 to AJson.Count - 1 do begin
          if (AJson.Items[I].ValueType = jvNumber) then
            LPArrInt^[I] := AJson.Items[I].AsInteger;
        end;
      end;
      tkClass : begin
        LPArrObj := PObjectDynArray(AValue.Raw^);
        SetLength(LPArrObj^, 0);
        SetLength(LPArrObj^, AJson.Count);
        for I := 0 to AJson.Count - 1 do begin
          if (AJson.Items[I].ValueType = jvObject) then begin
            raise Exception.Create('Type unavailable for unmarshal');
            //RevertJsonToObject(AJson.Items[I].AsObject, nil, LObjectValue);
            //LPArrObj^[I] := LObjectValue;
          end;
        end;
      end;
      else raise Exception.Create('Type must be implemented');
  end;
end;

procedure TJsonReverter.RevertJsonToObject(const AJson: TJsonObject;
  const AValueType: PTypeInfo; const AValue: TTypedValue);
var
  LPropList: PPropList;
  LPropCount: Integer;
  I: Integer;
  LJsonValue: TJsonValue;
  LInstance: TObject;
  LDynArrayValue: Pointer;
  LSetValue: TIntegerSet;
  LDest: Pointer;
  LObjectValue: TObject;
  LTypeData: PTypeData;
  LValue: TTypedValue;
begin
  LInstance := AValue.AsObject;
  if not Assigned(LInstance) then begin
    LTypeData := GetTypeData(AValueType);
    LInstance := TTypeCreator.Instance.CreateInstance(LTypeData.ClassType);
    if not Assigned(LInstance) then
      raise Exception.Create('Type not available for unmarshal.');
    AValue.AsObject := LInstance;
  end;

  LPropCount := GetPropList(LInstance.ClassInfo, LPropList);
  for I := 0 to LPropCount - 1 do begin
    LJsonValue := AJson.Values[LPropList[i]^.Name];
    if not Assigned(LJsonValue) then
      Continue;                                                       
    case LPropList[i]^.PropType^.Kind of
      tkInteger, tkFloat, tkInt64, tkChar, {$IFDEF FPC} tkAString, {$ENDIF} tkLString, tkString, tkWChar, tkWString, tkEnumeration: begin
        TDataTypeManager.NewMem(LPropList[i]^.PropType^, LDest);
        try
          LValue := TTypedValue.Create(LPropList[I]^.PropType^, LDest^);
          try
            RevertJsonToObjectValueProp(LJsonValue, LInstance, LPropList[I]^.PropType^, LPropList[I]^.Name, LValue);
            SetPropValue(LInstance, LPropList[I], TDataTypeManager.ParseValToVar(LPropList[I]^.PropType^, Pointer(LDest^)));
          finally
            LValue.Free();
          end;
        finally
          TDataTypeManager.DispMem(LPropList[i]^.PropType^, LDest);
        end;
      end;
      tkClass: begin
        LObjectValue := GetObjectProp(LInstance, LPropList[i]^.Name);
        LValue := TTypedValue.Create(LPropList[I]^.PropType^, LObjectValue);
        try
          RevertJsonToObjectClassProp(LJsonValue, LInstance, LPropList[I]^.PropType^, LPropList[I]^.Name, LValue);
        finally
          LValue.Free();
        end;
      end;
      tkDynArray: begin
        LDynArrayValue := GetDynArrayProp(LInstance, LPropList[I]);
        LValue := TTypedValue.Create(LPropList[I]^.PropType^, LDynArrayValue);
        try
          RevertJsonToObjectArrayProp(LJsonValue, LInstance, LPropList[I]^.PropType^, LPropList[I]^.Name, LValue);
          SetDynArrayProp(LInstance, LPropList[I], LDynArrayValue);
        finally
          LValue.Free();
        end;
      end;
      tkSet: begin
        LSetValue := [];
        LValue := TTypedValue.Create(LPropList[I]^.PropType^, LSetValue);
        try
          RevertJsonToObjectSetProp(LJsonValue, LInstance, LPropList[I]^.PropType^, LPropList[I]^.Name, LValue);
          SetOrdProp(LInstance, LPropList[i], Integer(LSetValue));
        finally
          LValue.Free();
        end;
      end;
      else raise Exception.Create('Type must be implemented');
    end;
  end;
end;

procedure TJsonReverter.RevertJsonToObjectArrayProp(const AJson: TJsonValue;
  const AInstance: TObject; const AValueType: PTypeInfo; const AName: string;
  const AValue: TTypedValue);
var
  LReverter: TTypeReverterInfo;
begin
  LReverter := GetReverter(AInstance.ClassInfo, AName);
  if Assigned(LReverter) then
    LReverter.TypeReverter.Parse(AValueType, AValue, AJson)
  else begin
    if AJson.IsNull or AJson.IsEmpty then
      Exit;
    RevertFromJson(AJson, AValueType, AValue);
  end;
end;

procedure TJsonReverter.RevertJsonToObjectClassProp(const AJson: TJsonValue;
  const AInstance: TObject; const AValueType: PTypeInfo; const AName: string;
  const AValue: TTypedValue);
var
  LReverter: TTypeReverterInfo;
begin
  LReverter := GetReverter(AInstance.ClassInfo, AName);
  if Assigned(LReverter) then
    LReverter.TypeReverter.Parse(AValueType, AValue, AJson)
  else begin
    if AJson.IsNull or AJson.IsEmpty then
      Exit;
    RevertFromJson(AJson, AValueType, AValue);
  end;
end;

procedure TJsonReverter.RevertJsonToObjectSetProp(const AJson: TJsonValue;
  const AInstance: TObject; const AValueType: PTypeInfo; const AName: string;
  const AValue: TTypedValue);
var
  LReverter: TTypeReverterInfo;
begin
  LReverter := GetReverter(AInstance.ClassInfo, AName);
  if Assigned(LReverter) then
    LReverter.TypeReverter.Parse(AValueType, AValue, AJson)
  else begin
    if AJson.IsNull or AJson.IsEmpty then
      Exit;
    RevertFromJson(AJson, AValueType, AValue);
  end;
end;

procedure TJsonReverter.RevertJsonToObjectValueProp(const AJson: TJsonValue;
  const AInstance: TObject; const AValueType: PTypeInfo; const AName: string;
  const AValue: TTypedValue);
var
  LReverter: TTypeReverterInfo;
begin
  LReverter := GetReverter(AInstance.ClassInfo, AName);
  if Assigned(LReverter) then
    LReverter.TypeReverter.Parse(AValueType, AValue)
  else begin
    if AJson.IsNull or AJson.IsEmpty then
      Exit;
    RevertFromJson(AJson, AValueType, AValue);
  end;
end;

procedure TJsonReverter.RevertJsonToValue(const AJson: TJsonValue;
  const AValueType: PTypeInfo; const AValue: TTypedValue);
var
  LTypeData: PTypeData;
  LPTypeInfo: PTypeInfo;
  I: Integer;
  LSet: TIntegerSet;
begin
  if (AJson.IsNull) or (AJson.IsEmpty) then
    Exit;

  case AValueType^.Kind of
    tkInteger: begin
      if (AJson.ValueType = jvNumber) then
        AValue.AsInteger := AJson.AsInteger;
    end;
    tkFloat: begin
      if AValueType^.Name = 'TDateTime' then begin
        if (AJson.ValueType = jvString) then
          AValue.AsDateTime := JsonStringToDate(AJson.AsString);
      end else if AValueType^.Name = 'TDate' then begin
        if (AJson.ValueType = jvString) then
          AValue.AsExtended := JsonStringToDate(AJson.AsString);
      end else if AValueType^.Name = 'TTime' then begin
        if (AJson.ValueType = jvString) then
          AValue.AsDouble := JsonStringToDate(AJson.AsString);
      end else begin
        if (TJsonValue(AJson).ValueType = jvNumber) then
          AValue.AsExtended := AJson.AsNumber;
      end;
    end;
    tkInt64: begin
      if (AJson.ValueType = jvNumber) then
        AValue.AsInt64 := AJson.AsInteger;
    end;
    tkChar: begin
      if (AJson.ValueType = jvString) then
        AValue.AsChar := AJson.AsString[1];
    end;
    {$IFDEF FPC}
    tkAString,
    {$ENDIF}
    tkLString,
    tkString: begin
      if (AJson.ValueType = jvString) then
        AValue.AsString := AJson.AsString;
    end;
    tkWChar: begin
      if (AJson.ValueType = jvString) then
        AValue.AsWideChar := WideChar(AJson.AsString[1]);
    end;
    tkWString: begin
      if (AJson.ValueType = jvString) then
        AValue.AsWideString := WideString(AJson.AsString);
    end;
    tkEnumeration: begin
      if (AValueType^.Name = 'Boolean') then begin
        if (AJson.ValueType = jvBoolean) then
          AValue.AsBoolean := AJson.AsBoolean;
      end else begin
        AValue.AsInteger := AJson.AsInteger;
      end;
    end;
    tkSet: begin
      if (AJson.ValueType = jvArray) then begin
        LTypeData := GetTypeData(AValueType);
        LPTypeInfo := LTypeData.CompType^;
        LSet := [];
        for I := 0 to AJson.AsArray.Count - 1 do begin
          if (AJson.AsArray.Items[I].ValueType = jvString) then
            Include(LSet, GetEnumValue(LPTypeInfo, AJson.AsArray.Items[I].AsString));
        end;
        AValue.AsSet := LSet;
      end;
    end;
    else raise Exception.Create('Type must be implemented');
  end;
end;

{ TJsonUnMarshal }

constructor TJsonUnMarshal.Create(const AReverter: TJsonReverter);
begin
  FReverter := AReverter;
end;

destructor TJsonUnMarshal.Destroy;
begin
  FReverter.Free();
  inherited;
end;

class function TJsonUnMarshal.GetDefault: TJsonUnMarshal;
begin
  if not Assigned(FDefault) then
    FDefault := TJsonUnMarshal.Create(TJsonReverter.Create());
  Result := FDefault;
end;

procedure TJsonUnMarshal.RegisterReverter(const AClass: TClass;
  const APropName: string; const ATypeReverter: TCustomTypeReverter);
begin
  FReverter.RegisterReverter(AClass.ClassInfo, APropName, ATypeReverter);
end;

procedure TJsonUnMarshal.RegisterReverter(const AValueType: PTypeInfo;
  const ATypeReverter: TCustomTypeReverter);
begin
  FReverter.RegisterReverter(AValueType, EmptyStr, ATypeReverter);
end;

procedure TJsonUnMarshal.UnMarshal(const AJson: TJsonValue;
  const AValueType: PTypeInfo; var AValue);
var
  LValue: TTypedValue;
begin
  LValue := TTypedValue.Create(AValueType, AValue);
  try
    FReverter.RevertFromJson(AJson, AValueType, LValue);
  finally
    LValue.Free();
  end;
end;

procedure TJsonUnMarshal.UnMarshal(const AJson: TJsonValue;
  var AInstance: TObject);
begin
  UnMarshal(AJson, AInstance.ClassInfo, AInstance);
end;

procedure TJsonUnMarshal.UnMarshal(const AJson: string;
  var AInstance: TObject);
begin
  UnMarshal(AJson, AInstance.ClassInfo, AInstance);
end;

procedure TJsonUnMarshal.UnMarshal(const AJson: string;
  const AValueType: PTypeInfo; var AValue);
var
  LJson: TJson;
  LJsonValue: TJsonValue;
  LValue: TTypedValue;
begin
  LJson := TJson.Create();
  try
    LJson.Parse(AJson);
    LJsonValue := TJsonValue.Create(nil);
    try
      if LJson.StructType = jsObject then
        LJsonValue.AsObject := LJson.JsonObject
      else if LJson.StructType = jsArray then
        LJsonValue.AsArray := LJson.JsonArray
      else
        raise Exception.Create('Can''t parse json');

      LValue := TTypedValue.Create(AValueType, AValue);
      try
        FReverter.RevertFromJson(LJsonValue, AValueType, LValue);
      finally
        LValue.Free();
      end;
    finally
      LJsonValue.Free();
    end;
  finally
    LJson.Free();
  end;
end;

{ TDataTypeManager }

class procedure TDataTypeManager.CopyVar(const ASource: variant; var ADest);
begin
  case VarType(ASource) and VarTypeMask of
    varSmallInt: Move(TVarData(ASource).VSmallInt, ADest, SizeOf(SmallInt));
    varInteger: Move(TVarData(ASource).VInteger, ADest, SizeOf(Integer));
    varSingle: Move(TVarData(ASource).VSingle, ADest, SizeOf(Single));
    varDouble: Move(TVarData(ASource).VDouble, ADest, SizeOf(Double));
    varCurrency: Move(TVarData(ASource).VCurrency, ADest, SizeOf(Currency));
    varDate: Move(TVarData(ASource).VDate, ADest, SizeOf(TDateTime));
    varBoolean: Move(TVarData(ASource).VBoolean, ADest, SizeOf(WordBool));
    varShortInt: Move(TVarData(ASource).VShortInt, ADest, SizeOf(ShortInt));
    varByte: Move(TVarData(ASource).VByte, ADest, SizeOf(Byte));
    varWord: Move(TVarData(ASource).VWord, ADest, SizeOf(Word));
    varLongWord: Move(TVarData(ASource).VLongWord, ADest, SizeOf(LongWord));
    varInt64: Move(TVarData(ASource).VInt64, ADest, SizeOf(Int64));
    varString: Move(TVarData(ASource).VString, ADest, SizeOf(Char));
  else
    raise Exception.Create('Type not supported');
  end;
end;

class procedure TDataTypeManager.CopyVal(const ATypeInfo: PTypeInfo;
  const ASource: variant; var ADest: pointer; const ANewNem: boolean);
var
  LValSize: Integer;
  LTypeData: PTypeData;
begin
  LValSize := GetValTypeSize(ATypeInfo);

  if LValSize <= 0 then
    raise Exception.Create('Type size not found.');

  if ANewNem then ADest := AllocMem(LValSize);

  case ATypeInfo.Kind of
    tkInteger: begin
      Integer(ADest^) := ASource;
    end;
    tkFloat: begin
      if ATypeInfo^.Name = 'TDateTime' then begin
        TDateTime(ADest^) := ASource;
      end else if ATypeInfo^.Name = 'TDate' then begin
        Extended(ADest^) := ASource;
      end else if ATypeInfo^.Name = 'TTime' then begin
        Extended(ADest^) := ASource;
      end else if ATypeInfo^.Name = 'Double' then begin
        Double(ADest^) := ASource;
      end else begin
        Extended(ADest^) := ASource;
      end;
    end;
    tkInt64: begin
      Int64(ADest^) := ASource;
    end;
    tkChar: begin
      Char(ADest^) := VarToStr(ASource)[1];
    end;
    {$IFDEF FPC}
    tkAString,
    {$ENDIF}
    tkLString,
    tkString: begin
      String(ADest^) := ASource;
    end;
    tkWChar: begin
      WideChar(ADest^) := VarToWideStr(ASource)[1];
    end;
    tkWString: begin
      WideString(ADest^) := ASource;
    end;
    tkEnumeration: begin
      if (ATypeInfo^.Name = 'Boolean') then begin
        Boolean(ADest^) := ASource;
      end else begin
        LTypeData := GetTypeData(ATypeInfo);
        case LTypeData.OrdType of
          otSByte: ShortInt(ADest^) := ASource;
          otUByte: Byte(ADest^) := ASource;
          otSWord: SmallInt(ADest^) := ASource;
          otUWord: Word(ADest^) := ASource;
          otSLong: LongInt(ADest^) := ASource;
          otULong: Cardinal(ADest^) := ASource;
          else raise Exception.Create('Type not supported.');
        end
      end;
    end;
    tkSet,
    tkClass,
    tkDynArray,
    tkArray,
    tkUnknown,
    tkMethod,
    tkVariant,
    tkRecord,
    tkInterface: raise Exception.Create('Type must be implemented');
    else raise Exception.Create('Type must be implemented');
  end;
end;

class procedure TDataTypeManager.CopyVar(const ASource: variant;
  var ADest: pointer; const ANewNem: boolean);
var
  LIsArray: Boolean;
  LVarSize: Integer;
begin
  LVarSize := GetVarTypeSize(VarType(ASource), LIsArray);
  if LIsArray then
    raise Exception.Create('Array type not supported');

  if LVarSize <= 0 then
    raise Exception.Create('Type size not found.');

  if ANewNem then ADest := AllocMem(LVarSize);

  case VarType(ASource) and VarTypeMask of
    varSmallInt: begin
      Move(TVarData(ASource).VSmallInt, ADest^, LVarSize);
    end;
    varInteger: begin
      Move(TVarData(ASource).VInteger, ADest^, LVarSize);
    end;
    varSingle: begin
      Move(TVarData(ASource).VSingle, ADest^, LVarSize);
    end;
    varDouble: begin
      Move(TVarData(ASource).VDouble, ADest^, LVarSize);
    end;
    varCurrency: begin
      Move(TVarData(ASource).VCurrency, ADest^, LVarSize);
    end;
    varDate: begin
      Move(TVarData(ASource).VDate, ADest^, LVarSize);
    end;
    varBoolean: begin
      Move(TVarData(ASource).VBoolean, ADest^, LVarSize);
    end;
    varShortInt: begin
      Move(TVarData(ASource).VShortInt, ADest^, LVarSize);
    end;
    varByte: begin
      Move(TVarData(ASource).VByte, ADest^, LVarSize);
    end;
    varWord: begin
      Move(TVarData(ASource).VWord, ADest^, LVarSize);
    end;
    varLongWord: begin
      Move(TVarData(ASource).VLongWord, ADest^, LVarSize);
    end;
    varInt64: begin
      Move(TVarData(ASource).VInt64, ADest^, LVarSize);
    end;
    varString: begin
      VarToLStrProc(String(Pointer(ADest)^), TVarData(ASource));
    end
  else
    raise Exception.Create('Type not supported');
  end;
end;

class procedure TDataTypeManager.DispMem(const ATypeInfo: PTypeInfo;
  var AValue: Pointer);
var
  LValSize: Integer;
begin
  LValSize := GetValTypeSize(ATypeInfo);

  FreeMem(AValue, LValSize);
  AValue := nil;
end;

class procedure TDataTypeManager.DispMem(const ASource: variant;
  var AValue: Pointer);
var
  LIsArray: Boolean;
  LVarSize: Integer;
begin
  LVarSize := GetVarTypeSize(VarType(ASource), LIsArray);
  if LIsArray then
    raise Exception.Create('Array type not supported');

  FreeMem(AValue, LVarSize);
  AValue := nil;
end;

class function TDataTypeManager.GetValTypeSize(
  const ATypeInfo: PTypeInfo): integer;
var
  LTypeData: PTypeData;
begin
  Result := 0;
  case ATypeInfo.Kind of
    tkInteger: begin
      Result := Sizeof(Integer);
    end;
    tkFloat: begin
      if ATypeInfo^.Name = 'TDateTime' then begin
        Result := SizeOf(TDateTime);
      end else if ATypeInfo^.Name = 'TDate' then begin
        Result := SizeOf(Extended);
      end else if ATypeInfo^.Name = 'TTime' then begin
        Result := SizeOf(Extended);
      end else if ATypeInfo^.Name = 'Double' then begin
        Result := SizeOf(Double);
      end else begin
        Result := SizeOf(Extended);
      end;
    end;
    tkInt64: begin
      Result := SizeOf(Int64);
    end;
    tkChar: begin
      Result := SizeOf(Char);
    end;
    {$IFDEF FPC}
    tkAString,
    {$ENDIF}
    tkLString,
    tkString: begin
      Result := SizeOf(Pointer);
    end;
    tkWChar: begin
      Result := SizeOf(WideChar);
    end;
    tkWString: begin
      Result := SizeOf(Pointer);
    end;
    tkEnumeration: begin
      if (ATypeInfo^.Name = 'Boolean') then begin
        Result := SizeOf(Boolean);
      end else begin
        LTypeData := GetTypeData(ATypeInfo);
        case LTypeData.OrdType of
          otSByte: Result := SizeOf(ShortInt);
          otUByte: Result := SizeOf(Byte);
          otSWord: Result := SizeOf(SmallInt);
          otUWord: Result := SizeOf(Word);
          otSLong: Result := SizeOf(LongInt);
          otULong: Result := SizeOf(Cardinal);
          else raise Exception.Create('Type not supported.');
        end
      end;
    end;
    tkSet:;
    tkClass,
    tkDynArray,
    tkArray,
    tkUnknown,
    tkMethod,
    tkVariant,
    tkRecord,
    tkInterface: raise Exception.Create('Type must be implemented');
  end;
end;

class function TDataTypeManager.GetVarTypeSize(const AVarType: TVarType;
  var AIsArray: boolean): integer;
begin
  AIsArray := AVarType <> (AVarType and VarTypeMask);

  case AVarType and VarTypeMask of
    varSmallInt: result := SizeOf(SmallInt);
    varInteger:  result := SizeOf(Integer);
    varSingle:   result := SizeOf(Single);
    varDouble:   result := SizeOf(Double);
    varCurrency: result := SizeOf(Currency);
    varDate:     result := SizeOf(TDateTime);
    varOleStr:   result := SizeOf(PWideChar);
    varDispatch: result := SizeOf(Pointer);
    varError:    result := SizeOf(HRESULT);
    varBoolean:  result := SizeOf(WordBool);
    varUnknown:  result := SizeOf(Pointer);
    varShortInt: result := SizeOf(ShortInt);
    varByte:     result := SizeOf(Byte);
    varWord:     result := SizeOf(Word);
    varLongWord: result := SizeOf(LongWord);
    varInt64:    result := SizeOf(Int64);
    varString:   result := SizeOf(Pointer);
    varAny:      result := SizeOf(Pointer);
    varArray:    result := SizeOf(PVarArray);
    varByRef:    result := SizeOf(Pointer);
  else
    result := -1;  //unknown
  end;
end;

class procedure TDataTypeManager.NewMem(const ATypeInfo: PTypeInfo;
  var ADest: Pointer);
var
  LVarSize: Integer;
begin
  LVarSize := GetValTypeSize(ATypeInfo);

  if LVarSize <= 0 then
    raise Exception.Create('Type size not found.');

  ADest := AllocMem(LVarSize);
end;

class function TDataTypeManager.ParseValToVar(const ATypeInfo: PTypeInfo;
  const ASource): variant;
var
  LTypeData: PTypeData;
begin
case ATypeInfo.Kind of
    tkInteger: begin
      Result := PInteger(@ASource)^;
    end;
    tkFloat: begin
      if ATypeInfo^.Name = 'TDateTime' then begin
        Result := PDateTime(@ASource)^;
      end else if ATypeInfo^.Name = 'TDate' then begin
        Result := PExtended(@ASource)^;
      end else if ATypeInfo^.Name = 'TTime' then begin
        Result := PExtended(@ASource)^;
      end else if ATypeInfo^.Name = 'Double' then begin
        Result := PDouble(@ASource)^;
      end else begin
        Result := PExtended(@ASource)^;
      end;
    end;
    tkInt64: begin
      Result := PInt64(@ASource)^;
    end;
    tkChar: begin
      Result := PChar(@ASource)^;
    end;
    {$IFDEF FPC}
    tkAString,
    {$ENDIF}
    tkLString,
    tkString: begin
      Result := PString(@ASource)^;
    end;
    tkWChar: begin
      Result := PWideChar(ASource)^;
    end;
    tkWString: begin
      Result := PWideString(ASource)^;
    end;
    tkEnumeration: begin
      if (ATypeInfo^.Name = 'Boolean') then begin
        Result := PBoolean(@ASource)^;
      end else begin
        LTypeData := GetTypeData(ATypeInfo);
        case LTypeData.OrdType of
          otSByte: Result := PShortInt(@ASource)^;
          otUByte: Result := PByte(@ASource)^;
          otSWord: Result := PSmallInt(@ASource)^;
          otUWord: Result := PWord(@ASource)^;
          otSLong: Result := PLongInt(@ASource)^;
          otULong: Result := PCardinal(@ASource)^;
          else raise Exception.Create('Type not supported.');
        end
      end;
    end;
    tkSet,
    tkClass,
    tkDynArray,
    tkArray,
    tkUnknown,
    tkMethod,
    tkVariant,
    tkRecord,
    tkInterface: raise Exception.Create('Type must be implemented');
    else raise Exception.Create('Type must be implemented');
  end;
end;

initialization
  TJsonMarshal.FDefault := nil;
  TJsonUnMarshal.FDefault := nil;

finalization
  FreeAndNil(TJsonUnMarshal.FDefault);
  FreeAndNil(TJsonMarshal.FDefault);

end.
