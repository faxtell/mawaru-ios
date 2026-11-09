"use strict";

function shortText(value, max, field, allowEmpty = false) {
  if (typeof value !== "string") throw new Error(field + " must be text");
  const valueTrimmed = value.trim();
  if ((!allowEmpty && valueTrimmed.length === 0) || valueTrimmed.length > max) {
    throw new Error(field + " must contain " + (allowEmpty ? "0" : "1") + "–" + max + " characters");
  }
  return valueTrimmed;
}

function nextTurn(index, memberCount) {
  if (!Number.isInteger(index) || !Number.isInteger(memberCount) ||
      memberCount < 2 || memberCount > 5 || index < 0 || index >= memberCount) {
    throw new Error("Invalid baton state");
  }
  return (index + 1) % memberCount;
}

function isValidRequestId(value) {
  return typeof value === "string" &&
    /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/.test(value);
}

function normalizedInvite(value) {
  return typeof value === "string" && /^[0-9a-fA-F]{24}$/.test(value.trim())
    ? value.trim().toUpperCase() : null;
}

const stickerKinds = new Set([
  "heart", "ribbon", "bear", "strawberry", "flower", "sparkles", "cloud",
  "star", "paw", "letter", "cake", "rainbow", "cat", "coffee",
  "tapePink", "tapeMint", "tapeLavender"
]);

function checkedDecoration(raw) {
  if (raw == null) return {paper: 0, stickers: [], photos: []};
  if (typeof raw !== "object" || Array.isArray(raw) ||
      !Number.isInteger(raw.paper) || raw.paper < 0 || raw.paper > 3 ||
      !Array.isArray(raw.stickers) || raw.stickers.length > 24) {
    throw new Error("Invalid page decoration");
  }
  const seen = new Set();
  const stickers = raw.stickers.map((s) => {
    if (!s || typeof s !== "object" || Array.isArray(s) ||
        typeof s.id !== "string" ||
        !/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(s.id) ||
        seen.has(s.id.toUpperCase()) ||
        !stickerKinds.has(s.kind) ||
        !Number.isFinite(s.x) || s.x < 0.07 || s.x > 0.93 ||
        !Number.isFinite(s.y) || s.y < 0.1 || s.y > 0.9 ||
        !Number.isFinite(s.scale) || s.scale < 0.5 || s.scale > 2.5 ||
        !Number.isFinite(s.rotation) || s.rotation < -180 || s.rotation > 180) {
      throw new Error("Invalid page sticker");
    }
    seen.add(s.id.toUpperCase());
    return {
      id: s.id.toUpperCase(), kind: s.kind, x: s.x, y: s.y,
      scale: s.scale, rotation: s.rotation
    };
  });
  return {paper: raw.paper, stickers};
}

module.exports = {shortText, nextTurn, isValidRequestId, normalizedInvite, checkedDecoration};
