"use strict";
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {randomBytes, createHash} = require("node:crypto");
const {shortText, nextTurn, isValidRequestId, normalizedInvite, checkedDecoration} = require("./lib/logic");

initializeApp();
const db = getFirestore();
const callableOptions = {region: "asia-northeast1", maxInstances: 10};
const fail = (code, message) => { throw new HttpsError(code, message); };
function requireUser(request) {
  if (!request.auth) fail("unauthenticated", "Appleでサインインしてください。");
  return request.auth.uid;
}
function checked(value, max, label, allowEmpty = false) {
  try { return shortText(value, max, label, allowEmpty); }
  catch { fail("invalid-argument", label + "の文字数を確認してください。"); }
}
function bookRef(bookId) {
  if (typeof bookId !== "string" || !/^[A-Za-z0-9]{10,40}$/.test(bookId)) {
    fail("invalid-argument", "無効な日記帳です。");
  }
  return db.collection("notebooks").doc(bookId);
}
function memberIndex(book, uid) {
  return Array.isArray(book.memberIds) ? book.memberIds.indexOf(uid) : -1;
}
function digest(code) { return createHash("sha256").update(code).digest("hex"); }

exports.createNotebook = onCall(callableOptions, async (request) => {
  const uid = requireUser(request);
  const title = checked(request.data?.title, 60, "日記帳名");
  const displayName = checked(request.data?.displayName, 30, "名前");
  const cover = request.data?.cover;
  if (!Number.isInteger(cover) || cover < 0 || cover > 3) fail("invalid-argument", "無効な表紙です。");
  const ref = db.collection("notebooks").doc();
  await ref.create({
    title, cover, ownerId: uid, memberIds: [uid], memberNames: [displayName],
    currentTurn: 0, lastSequence: 0, paused: false,
    createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
  });
  return {bookId: ref.id};
});

exports.createInvitation = onCall(callableOptions, async (request) => {
  const uid = requireUser(request);
  const ref = bookRef(request.data?.bookId);
  const code = randomBytes(12).toString("hex").toUpperCase(); // 96-bit single-use secret
  const inviteRef = db.collection("invites").doc(digest(code));
  const expiresAt = Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) fail("not-found", "日記帳が見つかりません。");
    const book = snap.data();
    if (memberIndex(book, uid) < 0) fail("permission-denied", "参加者のみ招待できます。");
    if (book.memberIds.length >= 5) fail("failed-precondition", "参加者は5人までです。");
    tx.create(inviteRef, {
      notebookId: ref.id, createdBy: uid, expiresAt,
      usedBy: null, createdAt: FieldValue.serverTimestamp(),
    });
  });
  return {code, expiresAt: expiresAt.toMillis()};
});

exports.redeemInvitation = onCall(callableOptions, async (request) => {
  const uid = requireUser(request);
  const code = normalizedInvite(request.data?.code);
  if (!code) fail("invalid-argument", "24文字の招待コードを入力してください。");
  const displayName = checked(request.data?.displayName, 30, "名前");
  const inviteRef = db.collection("invites").doc(digest(code));
  return db.runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) fail("not-found", "招待コードが見つかりません。");
    const invite = inviteSnap.data();
    if (invite.usedBy) {
      if (invite.usedBy === uid) return {bookId: invite.notebookId, alreadyJoined: true};
      fail("failed-precondition", "この招待コードは使用済みです。");
    }
    if (!invite.expiresAt || invite.expiresAt.toMillis() < Date.now()) {
      fail("deadline-exceeded", "招待コードの期限が切れています。");
    }
    const ref = bookRef(invite.notebookId);
    const snap = await tx.get(ref);
    if (!snap.exists) fail("not-found", "日記帳が見つかりません。");
    const book = snap.data();
    const currentMember = memberIndex(book, uid);
    if (currentMember >= 0) {
      tx.update(inviteRef, {usedBy: uid, usedAt: FieldValue.serverTimestamp()});
      return {bookId: ref.id, alreadyJoined: true};
    }
    if (book.memberIds.length >= 5) fail("resource-exhausted", "この日記帳は満員です。");
    tx.update(ref, {
      memberIds: [...book.memberIds, uid],
      memberNames: [...book.memberNames, displayName],
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(inviteRef, {usedBy: uid, usedAt: FieldValue.serverTimestamp()});
    return {bookId: ref.id, alreadyJoined: false};
  });
});

exports.submitEntry = onCall(callableOptions, async (request) => {
  const uid = requireUser(request);
  const ref = bookRef(request.data?.bookId);
  const requestId = request.data?.requestId;
  if (!isValidRequestId(requestId)) fail("invalid-argument", "投稿IDが無効です。");
  const title = checked(request.data?.title ?? "", 80, "タイトル", true);
  const body = checked(request.data?.body, 5000, "本文");
  let decoration;
  try { decoration = checkedDecoration(request.data?.decoration); }
  catch { fail("invalid-argument", "シールやノートのデザインが無効です。"); }
  const entryRef = ref.collection("entries").doc(requestId);
  return db.runTransaction(async (tx) => {
    const bookSnap = await tx.get(ref);
    if (!bookSnap.exists) fail("not-found", "日記帳が見つかりません。");
    const book = bookSnap.data();
    const index = memberIndex(book, uid);
    if (index < 0) fail("permission-denied", "この日記帳のメンバーではありません。");
    const old = await tx.get(entryRef);
    if (old.exists) {
      if (old.data().authorId !== uid) fail("already-exists", "同じ投稿IDが利用されています。");
      return {entryId: entryRef.id, duplicate: true};
    }
    if (book.paused) fail("failed-precondition", "日記帳は休止中です。");
    if (book.memberIds.length < 2) fail("failed-precondition", "相手が参加するまでお待ちください。");
    if (index !== book.currentTurn) fail("failed-precondition", "今はあなたの番ではありません。");
    const sequence = (book.lastSequence || 0) + 1;
    tx.create(entryRef, {
      authorId: uid, authorName: book.memberNames[index],
      title, body, sequence, decoration,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(ref, {
      currentTurn: nextTurn(book.currentTurn, book.memberIds.length),
      lastSequence: sequence, updatedAt: FieldValue.serverTimestamp(),
    });
    return {entryId: entryRef.id, duplicate: false};
  });
});

exports.setNotebookPaused = onCall(callableOptions, async (request) => {
  const uid = requireUser(request);
  const ref = bookRef(request.data?.bookId);
  if (typeof request.data?.paused !== "boolean") fail("invalid-argument", "無効な値です。");
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) fail("not-found", "日記帳が見つかりません。");
    if (snap.data().ownerId !== uid) fail("permission-denied", "作成者のみ変更できます。");
    tx.update(ref, {paused: request.data.paused, updatedAt: FieldValue.serverTimestamp()});
  });
  return {ok: true};
});
