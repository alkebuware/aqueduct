part of monadart;

class ModelController<T extends Model> extends HttpController {
  QueryAdapter adapter;

  ModelController(this.adapter) : super() {

  }

  T requestModel;
  Query<T> query = new Query<T>();

  @override
  void willProcessRequest(ResourceRequest req) {
    var firstVarName = req.path.firstVariableName;
    if (firstVarName != null) {
      var idValue = req.path.variables[firstVarName];

      if (idValue != null) {
        var reflectedModel = reflectClass(T).newInstance(new Symbol(""), []);
        var actualModel = (reflectedModel.reflectee as T);
        var pk = actualModel.primaryKey;
        if (pk == null) {
          throw new QueryException(500, "$T does not have primary key", -1);
        }

        var backingType = actualModel.backingType;
        var primaryKeyDecl = backingType.declarations[new Symbol(pk)];
        var primaryKeyType = primaryKeyDecl.type;

        var predicate = null;
        var primaryKeyName = actualModel.primaryKey;
        if (primaryKeyType.isSubtypeOf(reflectType(idValue.runtimeType))) {
          query.predicate = new Predicate("$primaryKeyName = @pk", {"pk" : idValue});
          reflectedModel.setField(new Symbol(pk), idValue);
        } else {
          var sym = new Symbol("parse");
          var parseDecl = (primaryKeyType as ClassMirror).declarations[sym];
          if (parseDecl != null) {
            var value = primaryKeyType
                .invoke(sym, [idValue])
                .reflectee;
            query.predicate = new Predicate("$primaryKeyName = @pk", {"pk" : value});
          } else {
            throw new HttpResponseException(500, "Attempting to interpret path parameter as primary key of type $primaryKeyType, but the type did not match.");
          }
        }
      }
    }
    super.willProcessRequest(req);
  }

  @override
  void didDecodeRequestBody(Map <String, dynamic> bodyMap) {
    var reflectedModel = reflectClass(T).newInstance(new Symbol(""), []);
    requestModel = reflectedModel.reflectee;
    // The bodyMap can't define the id.
    if (requestModel.dynamicBacking[requestModel.primaryKey] != null) {
      throw new HttpResponseException(400, "HTTP Request body may not define the primary key of a model object.");
    }

    query.valueObject = requestModel;

    requestModel.readMap(bodyMap);
  }
}