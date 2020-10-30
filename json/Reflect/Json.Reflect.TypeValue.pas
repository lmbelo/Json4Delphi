unit Json.Reflect.TypeValue;

interface

uses
  TypInfo, SysUtils;

type
  TTypedValue = class
  private
    FValueType: PTypeInfo;
    FRaw: Pointer;
    function GetAsEnum: Integer;
    procedure SetAsEnum(const Value: Integer);
    function GetAsSet: TIntegerSet;
    procedure SetAsSet(const Value: TIntegerSet);
    function GetAsWideChar: WideChar;
    procedure SetAsWideChar(const Value: WideChar);
    function GetAsWideString: WideString;
    procedure SetAsWideString(const Value: WideString);
    function GetAsBoolean: Boolean;
    procedure SetAsBoolean(const Value: Boolean);
    function GetAsChar: char;
    procedure SetAsChar(const Value: char);
    function GetAsString: string;
    procedure SetAsString(const Value: string);
    function GetAsDouble: Double;
    procedure SetAsDouble(const Value: Double);
    function GetAsExtended: Extended;
    procedure SetAsExtended(const Value: Extended);
    function GetAsInt64: Int64;
    procedure SetAsInt64(const Value: Int64);
    function GetAsVariant: Variant;
    procedure SetAsVariant(const Value: Variant);
    function GetAsInteger: integer;
    procedure SetAsInteger(const Value: integer);
    function GetAsDateTime: TDateTime;
    procedure SetAsDateTime(const Value: TDateTime);
    function GetAsObject: TObject;
    procedure SetAsObject(const Value: TObject);
  public
    constructor Create(const AValueType: PTypeInfo; const AValue);

    property ValueType: PTypeInfo read FValueType;
    property Raw: Pointer read FRaw;
    property AsObject: TObject read GetAsObject write SetAsObject;
    property AsString: string read GetAsString write SetAsString;
    property AsChar: char read GetAsChar write SetAsChar;
    property AsWideString: WideString read GetAsWideString write SetAsWideString;
    property AsWideChar: WideChar read GetAsWideChar write SetAsWideChar;
    property AsInteger: integer read GetAsInteger write SetAsInteger;
    property AsInt64: Int64 read GetAsInt64 write SetAsInt64;
    property AsExtended: Extended read GetAsExtended write SetAsExtended;
    property AsDouble: Double read GetAsDouble write SetAsDouble;
    property AsDateTime: TDateTime read GetAsDateTime write SetAsDateTime;
    property AsBoolean: Boolean read GetAsBoolean write SetAsBoolean;
    property AsEnum: Integer read GetAsEnum write SetAsEnum;
    property AsSet: TIntegerSet read GetAsSet write SetAsSet;
    property AsVariant: Variant read GetAsVariant write SetAsVariant;
  end;

implementation

uses
  Json.Reflect.Exception, Variants;

{ TTypeValue }

constructor TTypedValue.Create(const AValueType: PTypeInfo; const AValue);
begin
  FValueType := AValueType;
  FRaw := Addr(AValue);
end;

function TTypedValue.GetAsBoolean: Boolean;
begin
  case FValueType^.Kind of
    tkInteger: begin
      Result := Boolean(PInteger(FRaw)^); 
    end;
    tkString: begin
      Result := StrToBool(PString(FRaw)^); 
    end;
    tkEnumeration: begin
      if (FValueType^.Name = 'Boolean') then begin
        Result := PBoolean(FRaw)^;
      end else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to boolean.', [FValueType^.Name]);;
    end;
    tkVariant: begin
      Result := PVariant(FRaw)^;
    end
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to boolean.', [FValueType^.Name]);
  end;
end;

function TTypedValue.GetAsChar: char;
begin
  if not (FValueType^.Kind = tkChar) then
    raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to char.', [FValueType^.Name]);
  Result := PChar(FRaw)^;
end;

function TTypedValue.GetAsDateTime: TDateTime;
begin
  case FValueType^.Kind of
    tkFloat: begin
      if FValueType^.Name = 'TDateTime' then begin
        Result := PDateTime(FRaw)^;
      end else if FValueType^.Name = 'TDate' then begin
        Result := PDate(FRaw)^;
      end else if FValueType^.Name = 'TTime' then begin
        Result := PDouble(FRaw)^;
      end else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to datetime.', [FValueType^.Name]);;
    end;
    tkVariant: begin
      Result := VarToDateTime(PVariant(FRaw)^);
    end;
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to datetime.', [FValueType^.Name]);  
  end;
end;

function TTypedValue.GetAsDouble: Double;
begin
  case FValueType^.Kind of
    tkFloat: begin
      if FValueType^.Name = 'Double' then begin
        Result := PDouble(FRaw)^;
      end else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to double.', [FValueType^.Name]);
    end;
    tkVariant: begin
      Result := PVariant(FRaw)^;
    end;
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to double.', [FValueType^.Name]);  
  end;
end;

function TTypedValue.GetAsEnum: Integer;
var
  LTypeData: PTypeData;
begin
  case FValueType^.Kind of
    tkEnumeration: begin
      if (FValueType^.Name = 'Boolean') then begin
        Result := Integer(PBoolean(FRaw)^);
      end else begin
        LTypeData := GetTypeData(FValueType);
        case LTypeData.OrdType of
          otSByte: Result := PShortInt(FRaw)^;
          otUByte: Result := PByte(FRaw)^;
          otSWord: Result := PSmallInt(FRaw)^;
          otUWord: Result := PWord(FRaw)^;
          otSLong: Result := PLongInt(FRaw)^;
          otULong: Result := PCardinal(FRaw)^;
          else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to integer.', [FValueType^.Name]);
        end;          
      end;
    end;
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to integer.', [FValueType^.Name]);
  end;
end;

function TTypedValue.GetAsExtended: Extended;
begin
  case FValueType^.Kind of
    tkFloat: begin
      if FValueType^.Name = 'TDateTime' then begin
        Result := PDateTime(FRaw)^;
      end else if FValueType^.Name = 'TDate' then begin
        Result := PDate(FRaw)^;
      end else if FValueType^.Name = 'TTime' then begin
        Result := PDouble(FRaw)^;
      end else begin
        Result := PExtended(FRaw)^;
      end;
    end;
    tkVariant: begin
      Result := PVariant(FRaw)^;
    end;
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to float.', [FValueType^.Name]);
  end;
end;

function TTypedValue.GetAsInt64: Int64;
begin
  if not (FValueType^.Kind = tkInt64) then
    raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to int64.', [FValueType^.Name]);
  Result := PInt64(FRaw)^;
end;

function TTypedValue.GetAsInteger: integer;
var
  LTypeData: PTypeData;
  LSetValue: TIntegerSet;
  I: Integer;
begin
  case FValueType^.Kind of
    tkInteger: begin
      Result := PInteger(FRaw)^;
    end;
    tkString: begin
      Result := StrToInt(PString(FRaw)^);
    end;
    tkEnumeration: begin
      if (FValueType^.Name = 'Boolean') then begin
        Result := Integer(PBoolean(FRaw)^);
      end else begin
        LTypeData := GetTypeData(FValueType);
        case LTypeData.OrdType of
          otSByte: Result := PShortInt(FRaw)^;
          otUByte: Result := PByte(FRaw)^;
          otSWord: Result := PSmallInt(FRaw)^;
          otUWord: Result := PWord(FRaw)^;
          otSLong: Result := PLongInt(FRaw)^;
          otULong: Result := PCardinal(FRaw)^;
          else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to integer.', [FValueType^.Name]);
        end;          
      end;
    end; 
    tkSet: begin
      LTypeData := GetTypeData(FValueType);
      case LTypeData.OrdType of
        otSByte: Integer(LSetValue) := PShortInt(FRaw)^;
        otUByte: Integer(LSetValue) := PByte(FRaw)^;
        otSWord: Integer(LSetValue) := PSmallInt(FRaw)^;
        otUWord: Integer(LSetValue) := PWord(FRaw)^;
        otSLong: Integer(LSetValue) := PLongInt(FRaw)^;
        otULong: Integer(LSetValue) := PCardinal(FRaw)^;
        else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to integer.', [FValueType^.Name]);
      end;
      Result := -1;
      for I := 0 to SizeOf(Integer) * 8 - 1 do
        if I in LSetValue then
          Include(TIntegerSet(Result), I);
    end;
    tkVariant: begin
      Result := PVariant(FRaw)^;
    end;
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to integer.', [FValueType^.Name]);
  end;
end;

function TTypedValue.GetAsObject: TObject;
begin
  if not (FValueType^.Kind = tkClass) then
    raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to object.', [FValueType^.Name]);
  Result := TObject(Pointer(FRaw)^);
end;

function TTypedValue.GetAsSet: TIntegerSet;
var
  LTypeData: PTypeData;
  LSetValue: TIntegerSet;
  I: Integer;
begin
  case FValueType^.Kind of    
    tkSet: begin
      LTypeData := GetTypeData(FValueType);
      case LTypeData.OrdType of
        otSByte: Integer(LSetValue) := PShortInt(FRaw)^;
        otUByte: Integer(LSetValue) := PByte(FRaw)^;
        otSWord: Integer(LSetValue) := PSmallInt(FRaw)^;
        otUWord: Integer(LSetValue) := PWord(FRaw)^;
        otSLong: Integer(LSetValue) := PLongInt(FRaw)^;
        otULong: Integer(LSetValue) := PCardinal(FRaw)^;
        else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to set.', [FValueType^.Name]);
      end;
      Result := [];
      for I := 0 to SizeOf(Integer) * 8 - 1 do
        if I in LSetValue then
          Include(TIntegerSet(Result), I);
    end 
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to set.', [FValueType^.Name]);
  end;
end;

function TTypedValue.GetAsString: string;
begin
  case FValueType^.Kind of
    {$IFDEF FPC} tkAString, {$ENDIF} tkLString, tkString: begin
      Result := PString(FRaw)^;
    end;
    tkEnumeration: begin
      Result := GetEnumName(FValueType, GetAsInteger());
    end;
    tkVariant: begin
      Result := VarToStr(PVariant(FRaw)^);
    end;
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to string.', [FValueType^.Name]);
  end;     
end;

function TTypedValue.GetAsVariant: Variant;
begin
  if not (FValueType^.Kind = tkVariant) then
    raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to variant.', [FValueType^.Name]);
  Result := PVariant(FRaw)^;
end;

function TTypedValue.GetAsWideChar: WideChar;
begin
  if not (FValueType^.Kind = tkWChar) then
    raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to wide char.', [FValueType^.Name]);
  Result := PWideChar(FRaw)^;
end;

function TTypedValue.GetAsWideString: WideString;
begin
  if not (FValueType^.Kind = tkWString) then
    raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to wide string.', [FValueType^.Name]);
  Result := PWideString(FRaw)^;
end;

procedure TTypedValue.SetAsBoolean(const Value: Boolean);
begin
  case FValueType^.Kind of
    tkInteger: begin
      PInteger(FRaw)^ := Integer(Value); 
    end;
    tkString: begin
      PString(FRaw)^ := BoolToStr(Value); 
    end;
    tkEnumeration: begin
      if (FValueType^.Name = 'Boolean') then begin
        PBoolean(FRaw)^ := Value;
      end else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to boolean.', [FValueType^.Name]);;
    end;
    tkVariant: begin
      PVariant(FRaw)^ := Value;
    end 
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to boolean.', [FValueType^.Name]);
  end;
end;

procedure TTypedValue.SetAsChar(const Value: char);
begin
  if not (FValueType^.Kind = tkChar) then
    raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to char.', [FValueType^.Name]);
  PChar(FRaw)^ := Value;
end;

procedure TTypedValue.SetAsDateTime(const Value: TDateTime);
begin
  case FValueType^.Kind of
    tkFloat: begin
      if FValueType^.Name = 'TDateTime' then begin
        PDateTime(FRaw)^ := Value;
      end else if FValueType^.Name = 'TDate' then begin
        PDate(FRaw)^ := Value;
      end else if FValueType^.Name = 'TTime' then begin
        PDouble(FRaw)^ := Value;
      end else begin
        PExtended(FRaw)^ := Value;
      end;
    end;
    tkVariant: begin
      PVariant(FRaw)^ := Value;
    end;
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to datetime.', [FValueType^.Name]);  
  end;
end;

procedure TTypedValue.SetAsDouble(const Value: Double);
begin
  case FValueType^.Kind of
    tkFloat: begin
      if FValueType^.Name = 'Double' then begin
        PDouble(FRaw)^ := Value;
      end;
    end;
    tkVariant: begin
      PVariant(FRaw)^ := Value;
    end;
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to double.', [FValueType^.Name]);
  end;
end;

procedure TTypedValue.SetAsEnum(const Value: Integer);
var
  LTypeData: PTypeData;
begin
  case FValueType^.Kind of
    tkEnumeration: begin
      if (FValueType^.Name = 'Boolean') then begin
        PBoolean(FRaw)^ := Boolean(Value);
      end else begin
        LTypeData := GetTypeData(FValueType);
        case LTypeData.OrdType of
          otSByte: PShortInt(FRaw)^ := Value;
          otUByte: PByte(FRaw)^ := Value; 
          otSWord: PSmallInt(FRaw)^ := Value; 
          otUWord: PWord(FRaw)^ := Value;
          otSLong: PLongInt(FRaw)^ := Value; 
          otULong: PCardinal(FRaw)^ := Value;
          else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to integer.', [FValueType^.Name]);
        end;          
      end;
    end;
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to integer.', [FValueType^.Name]);
  end;
end;

procedure TTypedValue.SetAsExtended(const Value: Extended);
begin
  case FValueType^.Kind of
    tkFloat: begin
      if FValueType^.Name = 'TDateTime' then begin
        PDateTime(FRaw)^ := Value;
      end else if FValueType^.Name = 'TDate' then begin
        PDate(FRaw)^ := Value;
      end else if FValueType^.Name = 'TTime' then begin
        PDouble(FRaw)^ := Value;
      end else begin
        PExtended(FRaw)^ := Value;
      end;
    end;
    tkVariant: begin
      PVariant(FRaw)^ := Value;
    end;
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to float.', [FValueType^.Name]);  
  end;
end;

procedure TTypedValue.SetAsInt64(const Value: Int64);
begin
  if not (FValueType^.Kind = tkInt64) then
    raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to int64.', [FValueType^.Name]);
  PInt64(FRaw)^ := Value;
end;

procedure TTypedValue.SetAsInteger(const Value: integer);
var
  LTypeData: PTypeData;
begin
  case FValueType^.Kind of
    tkInteger: begin
      PInteger(FRaw)^ := Value; 
    end;
    tkString: begin
      PString(FRaw)^ := IntToStr(Value); 
    end;
    tkEnumeration: begin
      if (FValueType^.Name = 'Boolean') then begin
        PBoolean(FRaw)^ := Boolean(Value);
      end else begin
        LTypeData := GetTypeData(FValueType);
        case LTypeData.OrdType of
          otSByte: PShortInt(FRaw)^ := Value;
          otUByte: PByte(FRaw)^ := Value; 
          otSWord: PSmallInt(FRaw)^ := Value; 
          otUWord: PWord(FRaw)^ := Value;
          otSLong: PLongInt(FRaw)^ := Value; 
          otULong: PCardinal(FRaw)^ := Value;
          else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to integer.', [FValueType^.Name]);
        end;          
      end;
    end;
    tkVariant: begin
      PVariant(FRaw)^ := Value;
    end;
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to integer.', [FValueType^.Name]);
  end;
end;

procedure TTypedValue.SetAsObject(const Value: TObject);
begin
  if not (FValueType^.Kind = tkClass) then
    raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to object.', [FValueType^.Name]);
  TObject(Pointer(FRaw)^) := Value;
end;

procedure TTypedValue.SetAsSet(const Value: TIntegerSet);
begin
  case FValueType^.Kind of
    tkSet: begin
      TIntegerSet(FRaw^) := Value;
    end 
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to set.', [FValueType^.Name]);
  end;
end;

procedure TTypedValue.SetAsString(const Value: string);
begin
  case FValueType^.Kind of
    {$IFDEF FPC} tkAString, {$ENDIF} tkLString, tkString: begin
      PString(FRaw)^ := Value;
    end;
    tkEnumeration: begin
      SetAsInteger(GetEnumValue(FValueType, Value));
    end;
    tkVariant: begin
      PVariant(FRaw)^ := Value;
    end;
    else raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to string.', [FValueType^.Name]);
  end;      
end;

procedure TTypedValue.SetAsVariant(const Value: Variant);
begin
  if not (FValueType^.Kind = tkVariant) then
    raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to variant.', [FValueType^.Name]);
  PVariant(FRaw)^ := Value;
end;

procedure TTypedValue.SetAsWideChar(const Value: WideChar);
begin
  if not (FValueType^.Kind = tkWChar) then
    raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to wide char.', [FValueType^.Name]);
  PWideChar(FRaw)^ := Value;
end;

procedure TTypedValue.SetAsWideString(const Value: WideString);
begin
  if not (FValueType^.Kind = tkWString) then
    raise EInvalidValueTypeConversion.CreateFmt('Can''t convert type %s to wide string.', [FValueType^.Name]);
  PWideString(FRaw)^ := Value;
end;

end.
