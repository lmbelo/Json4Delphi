unit Json.Reflect.Model;

interface

uses
  Classes, Contnrs;

type
  {$M+}
  TModel = class
  private
    FOwner: TModel;
    FList: TList;
    FMenaged: boolean;
    procedure SetMenage(const Value: boolean);
    procedure AddModel(const AModel: TModel);
    procedure RemoveModel(const AModel: TModel);
  private
    procedure CreateDependencies();
    procedure DispatchDependencies();
  protected
    procedure CreateDependency(const AName: string; const AClass: TClass; var AValue: TObject); virtual;
    procedure DispatchDependency(const AName: string; const AClass: TClass; const AValue: TObject); virtual;
  public
    constructor Create(const AOwner: TModel; const AManaged: boolean); overload; virtual;
    constructor Create(const AOwner: TModel); overload; virtual;
    constructor Create(const AManaged: boolean); overload; virtual;
    constructor Create(); overload; virtual;
    destructor Destroy(); override;

    property Managed: boolean read FMenaged write SetMenage default true;
  end;
  {$M-}

  TModelClass = class of TModel;

implementation

uses
  TypInfo, SysUtils, Json.Reflect.TypeCreator;

{ TModel }

constructor TModel.Create(const AOwner: TModel; const AManaged: boolean);
begin
  inherited Create();
  FOwner := AOwner;
  FMenaged := AManaged;
  FList := TList.Create();
  if Assigned(AOwner) then
    AOwner.AddModel(Self);
  if FMenaged then CreateDependencies();
end;

constructor TModel.Create(const AManaged: boolean);
begin
  Create(nil, AManaged);
end;

constructor TModel.Create(const AOwner: TModel);
begin
  Create(AOwner, true);
end;

destructor TModel.Destroy;
var
  I: Integer;
 begin
  if FMenaged then DispatchDependencies();
  if Assigned(FOwner) then
    FOwner.RemoveModel(Self);
  for I := FList.Count - 1 downto 0 do begin
    TModel(FList[I]).Free();
  end;
  FList.Free();
  inherited;
end;

procedure TModel.CreateDependencies;
var
  LPropCount: Integer;
  LPropList: PPropList;
  I: Integer;
  LInstance: TObject;
begin
  LPropCount := GetPropList(Self.ClassInfo, LPropList);
  for I := 0 to LPropCount - 1 do begin
    if (LPropList[I]^.PropType^.Kind = tkClass) then begin
      if not Assigned(LPropList[I]^.SetProc) then
        raise Exception.CreateFmt('Property %s is readonly.', [Self.ClassName + '.' + LPropList[I]^.Name]);

      LInstance := GetObjectProp(Self, LPropList[I]^.Name);
      if not Assigned(LInstance) then begin
        CreateDependency(LPropList[I]^.Name, GetObjectPropClass(LPropList[I]), LInstance);
        SetObjectProp(Self, LPropList[I]^.Name, LInstance);
      end;
    end;
  end;
end;

procedure TModel.DispatchDependencies;
var
  LPropCount: Integer;
  LPropList: PPropList;
  I: Integer;
  LInstance: TObject;
begin
  LPropCount := GetPropList(Self.ClassInfo, LPropList);
  for I := 0 to LPropCount - 1 do begin
    if (LPropList[I]^.PropType^.Kind = tkClass) then begin
      LInstance := GetObjectProp(Self, LPropList[I]^.Name);
      if Assigned(LInstance) then begin
        DispatchDependency(LPropList[I]^.Name, GetObjectPropClass(LPropList[I]), LInstance);
        SetObjectProp(Self, LPropList[I]^.Name, nil);
      end;
    end;
  end;
end;

procedure TModel.CreateDependency(const AName: string; const AClass: TClass;
  var AValue: TObject);
begin
  AValue := TTypeCreator.Instance.CreateInstance(AClass);
  if not Assigned(AValue) then
    AValue := AClass.Create();
end;

procedure TModel.DispatchDependency(const AName: string; const AClass: TClass;
  const AValue: TObject);
begin
  AValue.Free();
end;

procedure TModel.AddModel(const AModel: TModel);
begin
  FList.Add(AModel);
end;

procedure TModel.RemoveModel(const AModel: TModel);
begin
  FList.Remove(AModel);
end;

procedure TModel.SetMenage(const Value: boolean);
begin
  FMenaged := Value;
  if Value then CreateDependencies();
end;

constructor TModel.Create;
begin
  Create(nil, true);
end;

function TModelCreator(const AClass: TClass): TObject;
begin
  Result := TModelClass(AClass).Create();
end;

initialization
  TTypeCreator.Instance.RegisterCreator(TModel, TModelCreator);

finalization
  TTypeCreator.Instance.UnRegisterCreator(TModel);

end.
