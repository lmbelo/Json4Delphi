unit Json.Reflect.Exception;

interface

uses
  SysUtils;

type
  ETypeNotParsed = class(Exception)
  end;

  EInvalidValueTypeConversion = class(Exception)
  end;

implementation

end.
