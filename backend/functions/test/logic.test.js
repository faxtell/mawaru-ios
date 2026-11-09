"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {shortText, nextTurn, isValidRequestId, normalizedInvite, checkedDecoration} = require("../lib/logic");

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

test("a valid sticker sheet is retained and normalized", () => {
  const input = {paper: 2, stickers: [{
    id: "a04092ff-a08b-48e0-a67c-4f9c604270a0", kind: "tapePink",
    x: 0.5, y: 0.4, scale: 1.4, rotation: -12
  }]};
  const result = checkedDecoration(input);
  assert.equal(result.paper, 2);
  assert.equal(result.stickers[0].kind, "tapePink");
  assert.equal(result.stickers[0].id, input.stickers[0].id.toUpperCase());
  assert.deepEqual(checkedDecoration(), {paper: 0, stickers: [], photos: []});
});
test("invalid decoration, sticker sizes and duplicate IDs are rejected", () => {
  const s = {
    id: "a04092ff-a08b-48e0-a67c-4f9c604270a0",
    kind: "heart", x: 0.5, y: 0.5, scale: 1, rotation: 0
  };
  assert.throws(() => checkedDecoration({paper: 4, stickers: []}));
  assert.throws(() => checkedDecoration({paper: 0, stickers: [s, s]}));
  assert.throws(() => checkedDecoration({paper: 0, stickers: [{...s, x: -1}]}));
  assert.throws(() => checkedDecoration({paper: 0, stickers: [{...s, scale: 40}]}));
  assert.throws(() => checkedDecoration({paper: 0, stickers: [{...s, kind: "not-a-sticker"}]}));
  assert.throws(() => checkedDecoration({paper: 0, stickers: Array(25).fill(s)}));
});

test("a copied photo with bounded position and format passes validation", () => {
  const photo = {id: "a04092ff-a08b-48e0-a67c-4f9c604270a0", format: "png",
    x: 0.55, y: 0.45, scale: 1.2, rotation: 8};
  const result = checkedDecoration({paper: 1, stickers: [], photos: [photo]});
  assert.equal(result.photos.length, 1);
  assert.equal(result.photos[0].format, "png");
  assert.equal(result.photos[0].id, photo.id.toUpperCase());
});
test("oversized, repeated, and malformed photo stickers fail", () => {
  const photo = {id: "a04092ff-a08b-48e0-a67c-4f9c604270a0", format: "jpg",
    x: 0.5, y: 0.5, scale: 1, rotation: 0};
  const ok = (photos) => ({paper: 0, stickers: [], photos});
  assert.throws(() => checkedDecoration(ok([photo, photo])));
  assert.throws(() => checkedDecoration(ok([{...photo, format:"gif"}])));
  assert.throws(() => checkedDecoration(ok([{...photo, x:-1}])));
  assert.throws(() => checkedDecoration(ok([{...photo, id:"../escape"}])));
  assert.throws(() => checkedDecoration(ok(Array(5).fill(photo))));
});
