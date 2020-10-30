unit Json.Reflect.TypeInfo;

interface

uses
  TypInfo, SysUtils, Json.Reflect.Parser;

type
  TTypeConverterInfo = class
  private
    FValueType: PTypeInfo;
    FValueName: string;
    FTypeConverter: TCustomTypeConverter;
  public
    constructor Create(const AValueType: PTypeInfo; const AValueName: string; const ATypeConverter: TCustomTypeConverter);
    destructor Destroy(); override;

    property ValueType: PTypeInfo read FValueType write FValueType;
    property ValueName: string read FValueName write FValueName;
    property TypeConverter: TCustomTypeConverter read FTypeConverter write FTypeConverter;
  end;

  TTypeReverterInfo = class
  private       
    FValueType: PTypeInfo;
    FValueName: string;
    FTypeReverter: TCustomTypeReverter;
  public
    constructor Create(const AValueType: PTypeInfo; const AValueName: string; const ATypeReverter: TCustomTypeReverter);
    destructor Destroy(); override;

    property ValueType: PTypeInfo read FValueType write FValueType;
    property ValueName: string read FValueName write FValueName;
    property TypeReverter: TCustomTypeReverter read FTypeReverter write FTypeReverter;
  end;

implementation

{ TTypeConverterInfo }

constructor TTypeConverterInfo.Create(const AValueType: PTypeInfo;
  const AValueName: string; const ATypeConverter: TCustomTypeConverter);
begin
  inherited Create();
  FValueType := AValueType;
  FValueName := AValueName;
  FTypeConverter := ATypeConverter;
end;

destructor TTypeConverterInfo.Destroy;
begin
  FTypeConverter.Free();
  inherited;
end;

{ TTypeReverterInfo }

constructor TTypeReverterInfo.Create(const AValueType: PTypeInfo;
  const AValueName: string; const ATypeReverter: TCustomTypeReverter);
begin
  inherited Create();
  FValueType := AValueType;
  FValueName := AValueName;
  FTypeReverter := ATypeReverter;
end;

destructor TTypeReverterInfo.Destroy;
begin
  FTypeReverter.Free();
  inherited;
end;

end.
