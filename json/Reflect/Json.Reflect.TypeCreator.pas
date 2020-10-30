unit Json.Reflect.TypeCreator;

interface

uses
  Contnrs;

type
  TTypeCreatorAction = function(const AClass: TClass): TObject;
  
  TTypeCreator = class
  private
    class function GetInstance: TTypeCreator; static; type
    TClassCreator = class
    private
      FClazz: TClass;
      FCreator: TTypeCreatorAction;
    public
      constructor Create(const AClass: TClass; const ACreator: TTypeCreatorAction);
      property Clazz: TClass read FClazz write FClazz;
      property Creator: TTypeCreatorAction read FCreator write FCreator;
    end;
  private
    FCreators: TObjectList;
    function Find(const AClass: TClass; const AAbsolute: boolean): integer;
  private
    class var FInstance: TTypeCreator;
  public
    constructor Create();
    destructor Destroy(); override;

    function CreateInstance(const AClass: TClass; const AAbsolute: boolean = false): TObject;

    procedure RegisterCreator(const AClass: TClass; const ACreator: TTypeCreatorAction);
    procedure UnRegisterCreator(const AClass: TClass);
  public
    class property Instance: TTypeCreator read GetInstance;
  end;

implementation

uses
  TypInfo, SysUtils;

{ TDependencyCreator }

constructor TTypeCreator.Create;
begin
  FCreators := TObjectList.Create(true);
end;

destructor TTypeCreator.Destroy;
begin
  FCreators.Free();
  inherited;
end;

function TTypeCreator.CreateInstance(const AClass: TClass; const AAbsolute: boolean): TObject;
var
  LIndex: Integer;
begin
  LIndex := Find(AClass, AAbsolute);
  if (LIndex > -1) then
    Result := TClassCreator(FCreators[LIndex]).Creator(AClass)
  else
    Result := nil;
end;

function TTypeCreator.Find(const AClass: TClass; const AAbsolute: boolean): integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FCreators.Count - 1 do begin
    if (PTypeInfo(TClassCreator(FCreators[I]).Clazz.ClassInfo) = PTypeInfo(AClass.ClassInfo)) then begin
      Result := I;
      Break;
    end;
  end;
  if not AAbsolute and (Result = -1) then begin
    for I := 0 to FCreators.Count - 1 do begin
      if (AClass.InheritsFrom(TClassCreator(FCreators[I]).Clazz)) then begin
        Result := I;
        Break;
      end;
    end;
  end;
end;

class function TTypeCreator.GetInstance: TTypeCreator;
begin
  if not Assigned(FInstance) then
    FInstance := TTypeCreator.Create();
  Result := FInstance;
end;

procedure TTypeCreator.RegisterCreator(const AClass: TClass;
  const ACreator: TTypeCreatorAction);
var
  LIndex: Integer;
begin
  LIndex := Find(AClass, true);
  if LIndex > -1 then UnRegisterCreator(AClass);
  FCreators.Add(TClassCreator.Create(AClass, ACreator));
end;

procedure TTypeCreator.UnRegisterCreator(const AClass: TClass);
var
  LIndex: Integer;
begin
  LIndex := Find(AClass, true);
  FCreators.Remove(FCreators[LIndex]);
end;

{ TDependencyCreator.TClassCreator }

constructor TTypeCreator.TClassCreator.Create(const AClass: TClass;
  const ACreator: TTypeCreatorAction);
begin
  FClazz := AClass;
  FCreator := ACreator;
end;

initialization
  TTypeCreator.FInstance := nil;

finalization
  FreeAndNil(TTypeCreator.FInstance);

end.
