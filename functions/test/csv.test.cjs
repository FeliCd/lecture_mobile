const { test } = require("node:test"),
  assert = require("node:assert/strict");
const { preview, parseCsv } = require("../../scripts/import-roster.cjs");
test("roster import parses BOM, quoted comma/newline and reports row duplicate errors", () => {
  assert.deepEqual(parseCsv('\uFEFFa,b\r\n"one, two","x\ny"'), [
    ["a", "b"],
    ["one, two", "x\ny"],
  ]);
  const report = preview(
    'classCode,studentCode,fullName,email\r\nSE1928,SE001,"Nguyễn, A",a@example.test\r\nSE1928,SE001,B,\r\nSE1928,,C,\r\nSE1928,SE002,D,invalid',
  );
  assert.equal(report.valid.length, 1);
  assert.deepEqual(
    report.errors.map((e) => e.row),
    [3, 4, 5],
  );
});
