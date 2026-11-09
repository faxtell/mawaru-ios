"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {shortText, nextTurn, isValidRequestId, normalizedInvite} = require("../lib/logic");

test("baton moves through two-to-five members and wraps", () => {
  for (let count = 2; count <= 5; count++) {
    for (let turn = 0; turn < count; turn++) {
      assert.equal(nextTurn(turn, count), (turn + 1) % count);
    }
  }
});
test("invalid baton states reject", () => {
  assert.throws(() => nextTurn(0, 1));
  assert.throws(() => nextTurn(5, 5));
  assert.throws(() => nextTurn(-1, 3));
});
test("user input is length checked and trimmed", () => {
  assert.equal(shortText(" Hello ", 30, "name"), "Hello");
  assert.throws(() => shortText("  ", 30, "name"));
  assert.throws(() => shortText("x".repeat(31), 30, "name"));
  assert.equal(shortText(" ", 30, "title", true), "");
});
test("idempotency IDs and invitation codes require exact formats", () => {
  assert.ok(isValidRequestId("A04092FF-A08B-48E0-A67C-4F9C604270A0"));
  assert.ok(!isValidRequestId("../malicious"));
  assert.equal(normalizedInvite("abc123abc123abc123abc123"), "ABC123ABC123ABC123ABC123");
  assert.equal(normalizedInvite("guess"), null);
});
