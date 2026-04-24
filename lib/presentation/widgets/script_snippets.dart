class ScriptSnippet {
  final String category;
  final String title;
  final String code;
  final bool testsOnly;
  final bool preReqOnly;

  const ScriptSnippet({
    required this.category,
    required this.title,
    required this.code,
    this.testsOnly = false,
    this.preReqOnly = false,
  });
}

const List<ScriptSnippet> builtInScriptSnippets = [
  ScriptSnippet(
    category: 'Tests',
    title: 'Status code: Code is 200',
    testsOnly: true,
    code: '''pl.test("Status code is 200", function () {
  pl.expect(pl.response.code).to.eql(200);
});''',
  ),
  ScriptSnippet(
    category: 'Tests',
    title: 'Response body: Contains string',
    testsOnly: true,
    code: '''pl.test("Body matches string", function () {
  pl.expect(pl.response.text().includes("string_you_expect")).to.be.ok();
});''',
  ),
  ScriptSnippet(
    category: 'Tests',
    title: 'Response body: JSON value check',
    testsOnly: true,
    code: '''pl.test("JSON value check", function () {
  var jsonData = pl.response.json();
  pl.expect(jsonData["key"]).to.eql("expected_value");
});''',
  ),
  ScriptSnippet(
    category: 'Tests',
    title: 'Response body: Is equal to a string',
    testsOnly: true,
    code: '''pl.test("Body is equal to string", function () {
  pl.expect(pl.response.text()).to.eql("expected_string");
});''',
  ),
  ScriptSnippet(
    category: 'Tests',
    title: 'Response headers: Content-Type header check',
    testsOnly: true,
    code: '''pl.test("Content-Type is present", function () {
  var ct = pl.response.header("content-type");
  pl.expect(ct != null).to.be.ok();
});''',
  ),
  ScriptSnippet(
    category: 'Tests',
    title: 'Response time is less than 200ms',
    testsOnly: true,
    code: '''pl.test("Response time is less than 200ms", function () {
  pl.expect(pl.response.responseTime < 200).to.be.ok();
});''',
  ),
  ScriptSnippet(
    category: 'Tests',
    title: 'Status code: Successful POST request',
    testsOnly: true,
    code: '''pl.test("Successful POST request", function () {
  pl.expect(pl.response.code).to.eql(201);
});''',
  ),
  ScriptSnippet(
    category: 'Tests',
    title: 'Status code: Code name has string',
    testsOnly: true,
    code: '''pl.test("Status is OK", function () {
  pl.expect((pl.response.status || "").includes("OK")).to.be.ok();
});''',
  ),
  ScriptSnippet(
    category: 'Tests',
    title: 'Test',
    testsOnly: true,
    code: '''pl.test("Your test name", function () {
  var jsonData = pl.response.json();
  pl.expect(jsonData.value).to.eql(100);
});''',
  ),
  ScriptSnippet(
    category: 'Tests',
    title: 'Response body: Convert XML body to a JSON Object',
    testsOnly: true,
    code: '''var xmlText = pl.response.text();
pl.test("XML body is not empty", function () {
  pl.expect(xmlText != null && xmlText.length > 0).to.be.ok();
});''',
  ),
  ScriptSnippet(
    category: 'Tests',
    title: 'Use Tiny Validator for JSON data',
    testsOnly: true,
    code: '''pl.test("Schema validation", function () {
  var jsonData = pl.response.json();
  pl.expect(jsonData != null).to.be.ok();
});''',
  ),
  ScriptSnippet(
    category: 'Workflows',
    title: 'Send an HTTP request',
    code: '''pl.sendRequest({
  url: "https://example.com",
  method: "GET"
}, function (err, res) {
  // handle response
});''',
  ),
  ScriptSnippet(
    category: 'Workflows',
    title: 'Send an HTTP request from a Collection',
    code: '''const options = {
  collectionRequestId: 'your_request_id',
  // url: 'https://postman-echo.com/get', // Optional: override url
  // method: 'GET', // Optional: override method
  // headers: {
  //   'x-my-custom-header': 'some value'
  // }
};

pl.sendRequest(options, function (err, response) {
  if (err) {
    console.log(err);
  } else {
    console.log(response.json());
  }
});''',
  ),
  ScriptSnippet(
    category: 'Variables',
    title: 'Get an environment variable',
    code: '''var value = pl.environment.get("variable_key");''',
  ),
  ScriptSnippet(
    category: 'Variables',
    title: 'Set an environment variable',
    code: '''pl.environment.set("variable_key", "variable_value");''',
  ),
  ScriptSnippet(
    category: 'Variables',
    title: 'Get a global variable',
    code: '''var value = pl.globals.get("variable_key");''',
  ),
  ScriptSnippet(
    category: 'Variables',
    title: 'Set a global variable',
    code: '''pl.globals.set("variable_key", "variable_value");''',
  ),
  ScriptSnippet(
    category: 'Variables',
    title: 'Get a collection variable',
    code: '''var value = pl.collectionVariables.get("variable_key");''',
  ),
  ScriptSnippet(
    category: 'Variables',
    title: 'Set a collection variable',
    code: '''pl.collectionVariables.set("variable_key", "variable_value");''',
  ),
  ScriptSnippet(
    category: 'Variables',
    title: 'Get a variable',
    code: '''var value = pl.variables.get("variable_key");''',
  ),
  ScriptSnippet(
    category: 'Variables',
    title: 'Set a variable',
    code: '''pl.variables.set("variable_key", "variable_value");''',
  ),
  ScriptSnippet(
    category: 'Variables',
    title: 'Clear an environment variable',
    code: '''pl.environment.unset("variable_key");''',
  ),
  ScriptSnippet(
    category: 'Variables',
    title: 'Clear a global variable',
    code: '''pl.globals.unset("variable_key");''',
  ),
  ScriptSnippet(
    category: 'Variables',
    title: 'Clear a collection variable',
    code: '''pl.collectionVariables.unset("variable_key");''',
  ),
  ScriptSnippet(
    category: 'Variables',
    title: 'Clear a local variable',
    code: '''pl.variables.unset("variable_key");''',
  ),
];
