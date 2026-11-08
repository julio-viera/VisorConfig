const jsonSchema = 'JSON Schema';
const jsonSchemaWithComments = 'JSON Schema - With comments';
const jsonStandards = [
  jsonSchema,
  jsonSchemaWithComments,
  'RFC 8259',
  'ECMA-404',
];

bool usesJsonSchema(String? standard) =>
    standard == jsonSchema || standard == jsonSchemaWithComments;
