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

module.exports = {shortText, nextTurn, isValidRequestId, normalizedInvite};
