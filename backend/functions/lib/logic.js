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
  if (raw == null) return {paper: 0, stickers: [], photos: [], fontStyle: 0, fontSize: 18, inkStyle: 0, textAlignment: 0};
  if (typeof raw !== "object" || Array.isArray(raw) ||
      !Number.isInteger(raw.paper) || raw.paper < 0 || raw.paper > 3 ||
      !Array.isArray(raw.stickers) || raw.stickers.length > 24 ||
      (raw.photos !== undefined && (!Array.isArray(raw.photos) || raw.photos.length > 4))) {
    throw new Error("Invalid page decoration");
  }

  const style = raw.fontStyle ?? 0;
  const size = raw.fontSize ?? 18;
  const ink = raw.inkStyle ?? 0;
  const alignment = raw.textAlignment ?? 0;
  if (!Number.isInteger(style) || style < 0 || style > 3 ||
      !Number.isFinite(size) || size < 14 || size > 30 ||
      !Number.isInteger(ink) || ink < 0 || ink > 3 ||
      !Number.isInteger(alignment) || alignment < 0 || alignment > 2) {
    throw new Error("Invalid notebook typography");
  }

  const ids = new Set();
  function checkedPosition(p) {
    return Number.isFinite(p.x) && p.x >= 0.07 && p.x <= 0.93 &&
      Number.isFinite(p.y) && p.y >= 0.1 && p.y <= 0.9 &&
      Number.isFinite(p.scale) && p.scale >= 0.5 && p.scale <= 2.5 &&
      Number.isFinite(p.rotation) && p.rotation >= -180 && p.rotation <= 180;
  }
  function uniqueId(item) {
    if (!item || typeof item !== "object" || Array.isArray(item) ||
        typeof item.id !== "string" ||
        !/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(item.id) ||
        ids.has(item.id.toUpperCase()) || !checkedPosition(item)) {
      throw new Error("Invalid sticker placement");
    }
    const id = item.id.toUpperCase();
    ids.add(id);
    return id;
  }

  const stickers = raw.stickers.map((s) => {
    const id = uniqueId(s);
    if (!stickerKinds.has(s.kind)) throw new Error("Unknown sticker");
    return {id, kind: s.kind, x: s.x, y: s.y,
      scale: s.scale, rotation: s.rotation};
  });
  const photos = (raw.photos || []).map((p) => {
    const id = uniqueId(p);
    if (p.format !== "jpg" && p.format !== "png") {
      throw new Error("Unsupported image format");
    }
    return {id, format: p.format, x: p.x, y: p.y,
      scale: p.scale, rotation: p.rotation};
  });
  return {
    paper: raw.paper, stickers, photos,
    fontStyle: style, fontSize: size, inkStyle: ink, textAlignment: alignment
  };
}

module.exports = {shortText, nextTurn, isValidRequestId, normalizedInvite, checkedDecoration};
