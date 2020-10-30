unit Json.Reflect.Dictionary;

interface

uses
  Classes, Variants, Contnrs, TypInfo, Jsons,
  Json.Reflect.Parser, Json.Reflect.TypeInfo, Json.Reflect.TypeValue;

type
  TDictionary = class;

  TDictionaryList = class(TObjectList)
  private
    function GetItem(Index: Integer): TDictionary;
    procedure SetItem(Index: Integer; const Value: TDictionary);
  public
    function Add(): TDictionary;
    function First: TDictionary;
    function Last: TDictionary;

    property Items[Index: Integer]: TDictionary read GetItem write SetItem; default;
  end;

  TDictionary = class(TPersistent)
  private
    FData: TStrings;
    function GetValues(const Name: string): variant;
    procedure SetValues(const Name: string; const Value: variant);
  private
    //function GetValues: variant;
    function GetObjects(const Name: string): TDictionary;
    function GetArrays(const Name: string): TDictionaryList;
  public
    constructor Create();
    destructor Destroy(); override;

    property Values[const Name: string]: variant read GetValues write SetValues; default;
    property Objects[const Name: string]: TDictionary read GetObjects;
    property Arrays[const Name: string]: TDictionaryList read GetArrays;
  end;

  TDictionaryTypeConverter = class(TCustomTypeConverter)
  private
    FNameStack: string;
    procedure Enqueue(const AName: string);
    function Dequeue(): string;
  private
    function GetConverter(const ATypeInfo: PTypeInfo; const AName: string): TTypeConverterInfo;
    function Convert(const ADictionary: TDictionary): TJsonObject;
    function ConvertNamedData(const AVarData: variant): TJsonValue;
    function ConvertDictionary(const ADictionary: TDictionary): TJsonObject;
    function ConvertDictionaryList(const ADictionaryList: TDictionaryList): TJsonArray;
  public
    function Parse(const AValueType: PTypeInfo; const AValue: TTypedValue; const AArg: TObject = nil): TJsonValue; override;
  end;

  TDictionaryTypeReverter = class(TCustomTypeReverter)
  private
    FNameStack: string;
    procedure Enqueue(const AName: string);
    function Dequeue(): string;
  private
    function GetReverter(const ATypeInfo: PTypeInfo; const AName: string): TTypeReverterInfo;
    procedure Revert(const AJsonObject: TJsonObject; const ADictionary: TDictionary);
    procedure RevertNamedData(const AName: string; const AJsonValue: TJsonValue; const ADictionary: TDictionary);
    procedure RevertDictionary(const AJsonObject: TJsonObject; const ADictionary: TDictionary);
    procedure RevertDictionaryList(const AJsonArray: TJsonArray; const ADictionary: TDictionaryList);
  public
    function Parse(const AValueType: PTypeInfo; const AValue: TTypedValue; const AArg: TObject = nil): boolean; override;
  end;

implementation

uses
  SysUtils, ObjAuto, Json.Reflect.Model, Json.Reflect.TypeCreator;

type
  TDictionaryVariantType = class(TPublishableVariantType)
  protected
    function GetInstance(const V: TVarData): TObject; override;
  public
    procedure Clear(var V: TVarData); override;
    procedure Copy(var Dest: TVarData; const Source: TVarData;
      const Indirect: Boolean); override;
    function GetProperty(var Dest: TVarData; const V: TVarData;
      const Name: string): Boolean; override;
    function SetProperty(const V: TVarData; const Name: string;
      const Value: TVarData): Boolean; override;
    function DoProcedure(const V: TVarData; const Name: string;
      const Arguments: TVarDataArray): Boolean; override;  
    function DoFunction(var Dest: TVarData; const V: TVarData;
      const Name: string; const Arguments: TVarDataArray): Boolean; override;
  end;

  TDictionaryVarData = packed record
    VType: TVarType;
    Reserved1, Reserved2, Reserved3: Word;
    VDictionary: TObject;
    Reserved4: LongWord;
  end;

  TNamedData = class
  private
    FName: string;
    FData: variant;
    FOwned: boolean;
  public
    constructor Create(const AName: string; const AData: variant);
    destructor Destroy(); override;
    
    property Name: string read FName write FName;
    property Data: variant read FData write FData;
    //Owns class types
    property Owned: boolean read FOwned write FOwned;
  end;

var
  DictionaryVariantType: TDictionaryVariantType;
  
{ TDictionaryVariantType }

procedure TDictionaryVariantType.Clear(var V: TVarData);
begin
  inherited;
  V.VType := varEmpty;
  TDictionaryVarData(V).VDictionary := nil;
end;

procedure TDictionaryVariantType.Copy(var Dest: TVarData;
  const Source: TVarData; const Indirect: Boolean);
begin
  inherited;
  if Indirect and VarDataIsByRef(Source) then
    VarDataCopyNoInd(Dest, Source)
  else begin
    with TDictionaryVarData(Dest) do begin
      VType := VarType;
      VDictionary := TDictionaryVarData(Source).VDictionary;
    end;
  end;
end;

function TDictionaryVariantType.DoFunction(var Dest: TVarData;
  const V: TVarData; const Name: string;
  const Arguments: TVarDataArray): Boolean;
var
  LInstance: TObject;
  LMethodInfo: PMethodInfoHeader;
  LParamIndexes: array of Integer;
  LParams: array of Variant;
  I: Integer;
  LReturnValue: Variant;
begin
  LInstance := GetInstance(V);
  LMethodInfo := GetMethodInfo(LInstance, ShortString(Name));
  Result := Assigned(LMethodInfo);
  if Result then begin
    SetLength(LParamIndexes, Length(Arguments));
    SetLength(LParams, Length(Arguments));
    for I := Low(Arguments) to High(Arguments) do begin
      LParamIndexes[I] := I + 1;
      LParams[I] := Variant(Arguments[I]);
    end;
    LReturnValue := ObjectInvoke(LInstance, LMethodInfo, LParamIndexes, LParams);
    if not VarIsEmpty(LReturnValue) then
      VarCopy(Variant(Dest), LReturnValue);
  end else begin
    VarClear(Variant(Dest));
  end;
end;

function TDictionaryVariantType.DoProcedure(const V: TVarData;
  const Name: string; const Arguments: TVarDataArray): Boolean;
var
  LInstance: TObject;
  LMethodInfo: PMethodInfoHeader;
  LParamIndexes: array of Integer;
  LParams: array of Variant;
  I: Integer;
begin
  LInstance := GetInstance(V);
  LMethodInfo := GetMethodInfo(LInstance, ShortString(Name));
  Result := Assigned(LMethodInfo);
  if Result then begin
    SetLength(LParamIndexes, Length(Arguments));
    SetLength(LParams, Length(Arguments));
    for I := Low(Arguments) to High(Arguments) do begin
      LParamIndexes[I] := I + 1;
      LParams[I] := Variant(Arguments[I]);
    end;
    ObjectInvoke(LInstance, LMethodInfo, LParamIndexes, LParams);
  end;
end;

function TDictionaryVariantType.GetInstance(const V: TVarData): TObject;
begin
 Result := TDictionaryVarData(V).VDictionary;
end;

function TDictionaryVariantType.GetProperty(var Dest: TVarData;
  const V: TVarData; const Name: string): Boolean;
var
  LInstance: TDictionary;
  LIndex: Integer;
  //LNamedData: TNamedData;
begin
  LInstance := TDictionary(GetInstance(V));
  if IsPublishedProp(LInstance, Name) then begin
    Result := inherited GetProperty(Dest, V, Name);
  end else begin
    LIndex := LInstance.FData.IndexOf(Name);
    Result := LIndex > -1;
    if Result then begin
      //LNamedData := TNamedData(LInstance.FData.Objects[LIndex]);
      //Dest := LNamedData.Data;
    end;         
  end;  
end;

function TDictionaryVariantType.SetProperty(const V: TVarData;
  const Name: string; const Value: TVarData): Boolean;
var
  LInstance: TDictionary;
  LIndex: Integer;
  LNamedData: TNamedData;
begin
  LInstance := TDictionary(GetInstance(V));
  if IsPublishedProp(LInstance, Name) then begin
    Result := inherited SetProperty(V, Name, Value);
  end else begin
    LIndex := LInstance.FData.IndexOf(Name);
    if (LIndex > -1) then begin
      LNamedData := TNamedData(LInstance.FData.Objects[LIndex]);      
      LNamedData.Free();
      LInstance.FData.Delete(LIndex);
    end;
    //LInstance.FData.AddObject(Name, TNamedData.Create(Name, Value));
    Result := true;   
  end; 
end;

{ TDictionary }

constructor TDictionary.Create;
begin
  inherited;
  FData := TStringList.Create();
end;

destructor TDictionary.Destroy;
var
  I: Integer;
begin
  for I := 0 to FData.Count - 1 do
    FData.Objects[I].Free();
  FData.Free();
  inherited;
end;

//function TDictionary.GetValues: variant;
//begin
//  TDictionaryVarData(Result).VType := DictionaryVariantType.VarType;
//  TDictionaryVarData(Result).VDictionary := Self;
//end;

function TDictionary.GetObjects(const Name: string): TDictionary;
var
  LIndex: integer;
begin
  LIndex := FData.IndexOf(Name);
  if (LIndex > -1) then
    Result := TDictionary(FData.Objects[LIndex])
  else begin
    Result := TDictionary(FData.Objects[FData.AddObject(Name, TDictionary.Create())]);
  end;
end;

function TDictionary.GetValues(const Name: string): variant;
var
  LIndex: integer;
begin
  LIndex := FData.IndexOf(Name);
  if (LIndex > -1) then
    Result := Variant(TNamedData(FData.Objects[LIndex]).FData)
  else
    Result := Variant(TNamedData(FData.Objects[FData.AddObject(Name, TNamedData.Create(Name, Unassigned))]).FData);
end;

procedure TDictionary.SetValues(const Name: string; const Value: variant);
var
  LIndex: integer;
begin
  LIndex := FData.IndexOf(Name);
  if (LIndex > -1) then
    TNamedData(FData.Objects[LIndex]).FData := Value
  else
    TNamedData(FData.Objects[FData.AddObject(Name, TNamedData.Create(Name, Unassigned))]).FData := Value;
end;

function TDictionary.GetArrays(const Name: string): TDictionaryList;
var
  LIndex: integer;
begin
  LIndex := FData.IndexOf(Name);
  if (LIndex > -1) then
    Result := TDictionaryList(FData.Objects[LIndex])
  else begin
    Result := TDictionaryList(FData.Objects[FData.AddObject(Name, TDictionaryList.Create())]);
  end;
end;

{ TNamedData }

constructor TNamedData.Create(const AName: string; const AData: variant);
begin
  FOwned := true;
  FName := AName;
  FData := AData;
end;

destructor TNamedData.Destroy;
begin
  //if (FData.VType = 16457) and FOwned then
    //TObject(FData.VPointer^).Free();
  inherited;
end;

{ TDictionaryList }

function TDictionaryList.Add: TDictionary;
begin
  Result := Items[(inherited Add(TDictionary.Create()))];
end;

function TDictionaryList.First: TDictionary;
begin
  Result := TDictionary(inherited First);
end;

function TDictionaryList.GetItem(Index: Integer): TDictionary;
begin
  Result := TDictionary(inherited GetItem(Index));
end;

function TDictionaryList.Last: TDictionary;
begin
  Result := TDictionary(inherited Last);
end;

procedure TDictionaryList.SetItem(Index: Integer; const Value: TDictionary);
begin
  inherited SetItem(Index, Value);
end;

{ TDictionaryTypeConverter }

function TDictionaryTypeConverter.Convert(
  const ADictionary: TDictionary): TJsonObject;
var
  LData: TStrings;
  I: Integer;
  LJsonValue: TJsonBase;
begin
  Result := TJsonObject.Create();
  LData := ADictionary.FData;
  for I := 0 to LData.Count - 1 do begin
    Enqueue(LData[I]);
    try
      if (LData.Objects[I].InheritsFrom(TNamedData)) then begin
        LJsonValue := ConvertNamedData(TNamedData(LData.Objects[I]).Data);
        try
          Result.Put(LData[I], TJsonValue(LJsonValue));
        finally
          LJsonValue.Free();
        end;
      end else if (LData.Objects[I].InheritsFrom(TDictionary)) then begin
        LJsonValue := ConvertDictionary(TDictionary(LData.Objects[I]));
        try
          Result.Put(LData[I], TJsonObject(LJsonValue));
        finally
          LJsonValue.Free();
        end;
      end else if (LData.Objects[I].InheritsFrom(TDictionaryList)) then begin
        LJsonValue := ConvertDictionaryList(TDictionaryList(LData.Objects[I]));
        try
          Result.Put(LData[I], TJsonArray(LJsonValue));
        finally
          LJsonValue.Free();
        end;
      end;
    finally
      Dequeue();
    end;
  end;
end;

function TDictionaryTypeConverter.ConvertDictionary(
  const ADictionary: TDictionary): TJsonObject;
begin
  Result := Convert(ADictionary);
end;

function TDictionaryTypeConverter.ConvertDictionaryList(
  const ADictionaryList: TDictionaryList): TJsonArray;
var
  I: Integer;
begin
  Result := TJsonArray.Create();
  for I := 0 to ADictionaryList.Count - 1 do
    Result.Put(Convert(ADictionaryList[I]));
end;

function TDictionaryTypeConverter.ConvertNamedData(
  const AVarData: variant): TJsonValue;
var
  LIntValue: Integer;
  LDateTimeValue: TDateTime;
  LFloatValue: Double;
  LBoolValue: Boolean;
  LStrValue: string;
  LConverter: TTypeConverterInfo;
  LValue: TTypedValue;
begin
  LConverter := GetConverter(TDictionary.ClassInfo, FNameStack);
  case VarType(AVarData) of
    varEmpty: begin
      Result := TJsonValue.Create(nil);
      Result.IsEmpty := true;
    end;
    varNull: begin
      Result := TJsonValue.Create(nil);
      Result.IsNull := true;
    end;
    varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord, varInt64: begin
      LIntValue := Variant(AVarData);
      LValue := TTypedValue.Create(TypeInfo(Integer), LIntValue);
      try
        if Assigned(LConverter) then
          Result := TJsonValue(LConverter.TypeConverter.Parse(TypeInfo(Integer), LValue))
        else
          Result := TJsonValue(Converter.ConvertToJson(TypeInfo(Integer), LValue));
      finally
        LValue.Free();
      end;
    end;
    varSingle, varDouble, varCurrency: begin
      LFloatValue := Variant(AVarData);
      LValue := TTypedValue.Create(TypeInfo(Double), LFloatValue);
      try
        if Assigned(LConverter) then
          Result := TJsonValue(LConverter.TypeConverter.Parse(TypeInfo(Double), LValue))
        else
          Result := TJSonValue(Converter.ConvertToJson(TypeInfo(Double), LValue));
      finally
        LValue.Free();
      end;
    end;
    varDate: begin
      LDateTimeValue := Variant(AVarData);
      LValue := TTypedValue.Create(TypeInfo(TDateTime), LDateTimeValue);
      try
        if Assigned(LConverter) then
          Result := TJsonValue(LConverter.TypeConverter.Parse(TypeInfo(TDateTime), LValue))
        else
          Result := TJsonValue(Converter.ConvertToJson(TypeInfo(TDateTime), LValue));
      finally
        LValue.Free();
      end;
    end;
    varBoolean: begin
      LBoolValue := Variant(AVarData);
      LValue := TTypedValue.Create(TypeInfo(Boolean), LBoolValue);
      try
        if Assigned(LConverter) then
          Result := TJsonValue(LConverter.TypeConverter.Parse(TypeInfo(Boolean), LValue))
        else
          Result := TJsonValue(Converter.ConvertToJson(TypeInfo(Boolean), LValue));
      finally
        LValue.Free();
      end;
    end;
    varString: begin
      LStrValue := Variant(AVarData);
      LValue := TTypedValue.Create(TypeInfo(String), LStrValue);
      try
        if Assigned(LConverter) then
          Result := TJsonValue(LConverter.TypeConverter.Parse(TypeInfo(string), LValue))
        else
          Result := TJsonValue(Converter.ConvertToJson(TypeInfo(string), LValue));
      finally
        LValue.Free();
      end;
    end;
    else raise Exception.Create('Not implemented');
  end;
end;

function TDictionaryTypeConverter.Parse(const AValueType: PTypeInfo;
  const AValue: TTypedValue; const AArg: TObject = nil): TJsonValue;
var
  LJsonObject: TJsonObject;
begin
  LJsonObject := Convert(TDictionary(AValue.AsObject));
  try
    Result := TJsonValue.Create(nil);
    Result.AsObject := LJsonObject
  finally
    LJsonObject.Free();
  end;
end;

function TDictionaryTypeConverter.Dequeue: string;
begin
  while (Length(FNameStack) > 0) and (FNameStack[Length(FNameStack)] <> '.') do
    Delete(FNameStack, Length(FNameStack), 1);
  if Length(FNameStack) > 0 then
    Delete(FNameStack, Length(FNameStack), 1);
end;

procedure TDictionaryTypeConverter.Enqueue(const AName: string);
begin
  if (FNameStack <> EmptyStr) then
    FNameStack := FNameStack + '.';
  FNameStack := FNameStack + AName;
end;

function TDictionaryTypeConverter.GetConverter(const ATypeInfo: PTypeInfo;
  const AName: string): TTypeConverterInfo;
var
  LConverters: TObjectList;
  I: Integer;
  LConverter: TTypeConverterInfo;
begin
  Result := nil;
  LConverters := Converter.Converters;
  for I := 0 to LConverters.Count - 1 do begin
    if (LConverters[I] is TTypeConverterInfo) then begin
      LConverter := TTypeConverterInfo(LConverters[I]);
      if (LConverter.ValueType = ATypeInfo) and (LConverter.ValueName = AName) then begin
        Result := LConverter;
        Break;
      end;
    end;
  end;
end;

{ TDictionaryTypeReverter }

procedure TDictionaryTypeReverter.RevertDictionaryList(
  const AJsonArray: TJsonArray; const ADictionary: TDictionaryList);
var
  I: Integer;
  LJsonValue: TJsonValue;
begin
  for I := 0 to AJsonArray.Count - 1 do begin
    LJsonValue := AJsonArray.Items[I];
    case LJsonValue.ValueType of
      jvNone, jvNull, jvString, jvNumber, jvBoolean: raise Exception.Create('Not implemented');
      jvObject: RevertDictionary(LJsonValue.AsObject, ADictionary.Add());
      jvArray: raise Exception.Create('Not implemented');
    end;
  end;
end;

procedure TDictionaryTypeReverter.RevertDictionary(
  const AJsonObject: TJsonObject; const ADictionary: TDictionary);
var
  I: Integer;
begin
  for I := 0 to AJsonObject.Count - 1 do begin
    Enqueue(AJsonObject.Items[I].Name);
    try
      RevertNamedData(AJsonObject.Items[I].Name, AJsonObject.Items[I].Value, ADictionary);
    finally
      Dequeue();
    end;
  end;
end;

procedure TDictionaryTypeReverter.RevertNamedData(const AName: string;
  const AJsonValue: TJsonValue; const ADictionary: TDictionary);
var
  LReverter: TTypeReverterInfo;
  LVar: variant;
  LValue: TTypedValue;
begin
  LReverter := GetReverter(TDictionary.ClassInfo, FNameStack);
  if Assigned(LReverter) then begin
    LValue := TTypedValue.Create(TypeInfo(variant), LVar);
    try
      LReverter.TypeReverter.Parse(TypeInfo(variant), LValue, AJsonValue);
      ADictionary.Values[AName] := LVar;
    finally
      LValue.Free();
    end;
    Exit;
  end;

  case AJsonValue.ValueType of
    jvNone: ADictionary.Values[AName] := Unassigned;
    jvNull: ADictionary.Values[AName] := Null;
    jvString: ADictionary.Values[AName] := AJsonValue.AsString;
    jvNumber: ADictionary.Values[AName] := AJsonValue.AsNumber;
    jvBoolean: ADictionary.Values[AName] := AJsonValue.AsBoolean;
    jvObject: RevertDictionary(AJsonValue.AsObject, ADictionary.Objects[AName]);
    jvArray: RevertDictionaryList(AJsonValue.AsArray, ADictionary.Arrays[AName]);
  end;
end;

procedure TDictionaryTypeReverter.Revert(const AJsonObject: TJsonObject;
  const ADictionary: TDictionary);
var
  I: Integer;
begin                                                
  for I := 0 to AJsonObject.Count - 1 do begin
    Enqueue(AJsonObject.Items[I].Name);
    try
      case AJsonObject.Items[I].Value.ValueType of
        jvNone, jvNull, jvString, jvNumber, jvBoolean: RevertNamedData(AJsonObject.Items[I].Name, AJsonObject.Items[I].Value, ADictionary);
        jvObject: RevertDictionary(AJsonObject.Items[I].Value.AsObject, ADictionary.Objects[AJsonObject.Items[I].Name]);
        jvArray: RevertDictionaryList(AJsonObject.Items[I].Value.AsArray, ADictionary.Arrays[AJsonObject.Items[I].Name]);
      end;
    finally
      Dequeue();
    end;
  end;
end;

procedure TDictionaryTypeReverter.Enqueue(const AName: string);
begin
  if (FNameStack <> EmptyStr) then
    FNameStack := FNameStack + '.';
  FNameStack := FNameStack + AName;
end;

function TDictionaryTypeReverter.Dequeue: string;
begin
  while (Length(FNameStack) > 0) and (FNameStack[Length(FNameStack)] <> '.') do
    Delete(FNameStack, Length(FNameStack), 1);
  if Length(FNameStack) > 0 then
    Delete(FNameStack, Length(FNameStack), 1);
end;

function TDictionaryTypeReverter.GetReverter(const ATypeInfo: PTypeInfo;
  const AName: string): TTypeReverterInfo;
var
  I: Integer;
  LReverter: TTypeReverterInfo;
  LReverters: TObjectList;
begin
  Result := nil;
  LReverters := Reverter.Reverters;
  for I := 0 to LReverters.Count - 1 do begin
    if (LReverters[I] is TTypeReverterInfo) then begin
      LReverter := TTypeReverterInfo(LReverters[I]);
      if (LReverter.ValueType = ATypeInfo) and (LReverter.ValueName = AName) then begin
        Result := LReverter;
        Break;
      end;
    end;
  end;
end;

function TDictionaryTypeReverter.Parse(const AValueType: PTypeInfo;
  const AValue: TTypedValue; const AArg: TObject = nil): boolean;
var
  LJsonObject: TJsonObject;
begin
  Result := (AArg is TJsonObject) or ((AArg is TJsonValue) and (TJsonValue(AArg).ValueType = jvObject));
  if Result then begin
    if (AArg is TJsonObject) then
      LJsonObject := (AArg as TJsonObject)
    else
      LJsonObject := TJsonValue(AArg).AsObject;
    Revert(LJsonObject, TDictionary(AValue.AsObject));
  end;
end;

function TDictionaryCreator(const AClass: TClass): TObject;
begin
  Result := TDictionary.Create();
end;

initialization
  DictionaryVariantType := TDictionaryVariantType.Create;
  TTypeCreator.Instance.RegisterCreator(TDictionary, TDictionaryCreator);

finalization
  FreeAndNil(DictionaryVariantType);
  TTypeCreator.Instance.UnRegisterCreator(TDictionary);

end.
