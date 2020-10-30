unit Json.Reflect.List;

interface

uses
  Contnrs, Jsons, TypInfo, objauto, Json.Reflect.TypeValue, Json.Reflect.Parser;

type
  TTypedObjectListClass = class of TTypedObjectList;
  TTypedObjectList = class(TObjectList)
  private
    FItemClass: TClass;
    FMenaged: boolean;
  public
    constructor Create(const AClassType: TClass); overload;
    constructor Create(const AClassType: TClass; AOwnsObjects: Boolean); overload;

    function NewItem(): TObject; virtual;

    property ItemClass: TClass read FItemClass write FItemClass;
    property Managed: boolean read FMenaged write FMenaged default true;
  end;

  //{$METHODINFO ON}
  {$M+}
  TStaticallyTypedObjectList = class(TTypedObjectList)
  private const
    STATIC_ITEM_CLASS_PROPERTY_NAME = 'StaticItemClass';
  public
    function NewItem(): TObject; override;
  //Use declaration bellow on your class
  //published
    //property StaticItemClass: TItemClass read FStaticItemClass write FStaticItemClass;
  end;
  {$M-}

  TTypedObjectListTypeConverter = class(TCustomTypeConverter)
  public
    function Parse(const AValueType: PTypeInfo; const AValue: TTypedValue; const AArg: TObject = nil): TJsonValue; override;
  end;

  TTypedObjectListTypeReverter = class(TCustomTypeReverter)
  public
    function Parse(const AValueType: PTypeInfo; const AValue: TTypedValue; const AArg: TObject = nil): boolean; override;
  end;

implementation

uses
  SysUtils, Classes, Json.Reflect.TypeCreator, Json.Reflect.Model;

{ TObjectListModel }

constructor TTypedObjectList.Create(const AClassType: TClass);
begin
  Create(AClassType, true);
end;

constructor TTypedObjectList.Create(const AClassType: TClass;
  AOwnsObjects: Boolean);
begin
  inherited Create(AOwnsObjects);
  FItemClass := AClassType;
  FMenaged := true;
end;

function TTypedObjectList.NewItem: TObject;
begin
  Result := TTypeCreator.Instance.CreateInstance(FItemClass);
  if not Assigned(Result) then
    if FItemClass.InheritsFrom(TModel) then
      Result := TModelClass(FItemClass).Create()
    else
      Result := FItemClass.Create();
  Add(Result);
end;

{ TObjectListModelTypeConverter }

function TTypedObjectListTypeConverter.Parse(const AValueType: PTypeInfo;
  const AValue: TTypedValue; const AArg: TObject = nil): TJsonValue;
var
  LList: TTypedObjectList;
  LJsonArray: TJsonArray;
  I: Integer;
  LJsonObject: TJsonValue;
  LValue: TTypedValue;
  LObj: TObject;
begin
  Result := TJsonValue.Create(nil);
  
  LJsonArray := TJsonArray.Create();
  try
    LList := TTypedObjectList(AValue.AsObject);
    for I := 0 to LList.Count - 1 do begin
      LObj := LList[I];
      LValue := TTypedValue.Create(LObj.ClassInfo, LObj);
      try
        LJsonObject := Converter.ConvertToJson(LObj.ClassInfo, LValue);
        try
          if LJsonObject.ValueType = jvObject then begin
            LJsonArray.Put(LJsonObject.AsObject);
          end;
        finally
          LJsonObject.Free();
        end;
      finally
        LValue.Free();
      end;
    end;
    Result.AsArray := LJsonArray;
  finally
    LJsonArray.Free();
  end;
end;

{ TObjectListModelTypeReverter }

function TTypedObjectListTypeReverter.Parse(const AValueType: PTypeInfo;
  const AValue: TTypedValue; const AArg: TObject = nil): boolean;
var
  LList: TTypedObjectList;
  LJsonArray: TJsonArray;
  I: Integer;
  LObject: TObject;
  LValue: TTypedValue;
begin
  LList := TTypedObjectList(AValue.AsObject);
  LJsonArray := TJsonValue(AArg).AsArray;
  for I := 0 to LJsonArray.Count - 1 do begin
    if (LJsonArray.Items[I].ValueType = jvObject) then begin
      LObject := LList.NewItem();
      LValue := TTypedValue.Create(LObject.ClassInfo, LObject);
      try
        Reverter.RevertFromJson(LJsonArray.Items[I], LObject.ClassInfo, LValue);
      finally
        LValue.Free();
      end;
    end else begin
      Result := false;
      Exit;
    end;
  end;
  Result := true;
end;

{ TStaticallyTypedObjectList }

function TStaticallyTypedObjectList.NewItem: TObject;
begin
  if not IsPublishedProp(Self, STATIC_ITEM_CLASS_PROPERTY_NAME) then
    raise Exception.Create('"StaticItemClass" property not setted up');
  
  ItemClass := GetObjectPropClass(Self, STATIC_ITEM_CLASS_PROPERTY_NAME);

  Result := Inherited NewItem();
end;

function TypedObjectListCreator(const AClass: TClass): TObject;
begin
  if (AClass.InheritsFrom(TTypedObjectList)) then
    Result := TTypedObjectListClass(AClass).Create(nil, true)
  else
    Result := nil;
end;

initialization
  TTypeCreator.Instance.RegisterCreator(TTypedObjectList, TypedObjectListCreator);

finalization
  TTypeCreator.Instance.UnRegisterCreator(TTypedObjectList);

end.
