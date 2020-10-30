unit Json.Reflect.Parser;

interface

uses
  TypInfo, Jsons, Json.Reflect.Intf, Json.Reflect.TypeValue;

type
  TCustomTypeConverter = class abstract
  private
    FConverter: IJsonConverter;
  public
    property Converter: IJsonConverter read FConverter write FConverter;
  public
    function Parse(const AValueType: PTypeInfo; const AValue: TTypedValue; const AArg: TObject = nil): TJsonValue; virtual; abstract;
  end;

  TCustomTypeReverter = class abstract
  private
    FReverter: IJsonReverter;
  public
    property Reverter: IJsonReverter read FReverter write FReverter;
  public
    function Parse(const AValueType: PTypeInfo; const AValue: TTypedValue; const AArg: TObject = nil): boolean; virtual; abstract;
  end;

implementation

end.
