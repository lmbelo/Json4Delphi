unit Json.Reflect.Intf;

interface

uses
  TypInfo, Jsons, Contnrs, Json.Reflect.TypeValue;

type
  IJsonConverter = interface
    ['{B436DEDA-CD7C-4E66-90A0-578FF03A0C54}']
    function GetConverters(): TObjectList;
    function ConvertToJson(const AValueType: PTypeInfo; const AValue: TTypedValue): TJsonValue;

    property Converters: TObjectList read GetConverters;
  end;

  IJsonReverter = interface
    ['{EE13FBA0-E4EA-431A-9F96-01829D786A0B}']
    function GetReverters(): TObjectList;
    procedure RevertFromJson(const AJson: TJsonValue; const AValueType: PTypeInfo; const AValue: TTypedValue);

    property Reverters: TObjectList read GetReverters;
  end;

implementation

end.
