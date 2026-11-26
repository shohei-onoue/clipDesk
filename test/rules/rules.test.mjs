import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { before, after, beforeEach, test } from 'node:test';
import {
  initializeTestEnvironment, assertFails, assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, collection, getDocs, query, where,
} from 'firebase/firestore';
import { ref, uploadBytes, getBytes, deleteObject } from 'firebase/storage';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'clipdesk-rules-test',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
    storage: { rules: readFileSync('../../storage.rules', 'utf8'), host: '127.0.0.1', port: 9199 },
  });
});
after(() => env.cleanup());

const REQ = 'req', ED = 'ed', ED2 = 'ed2', OTHER = 'other', NOROLE = 'norole', STAFF = 'staff1', MGR = 'mgr';
const ctxs = new Map();
const ctx = (uid) => { if (!ctxs.has(uid)) ctxs.set(uid, env.authenticatedContext(uid)); return ctxs.get(uid); };
const db = (uid) => ctx(uid).firestore();
const st = (uid) => ctx(uid).storage();
const brief = { purpose: 'p', structure: 's', deliveryTerms: 'd', scenes: [] };

const newReq = (over = {}) => ({
  requesterId: REQ, editorId: null, status: 'pending', title: 't', brief,
  dueDate: new Date('2026-12-01'), attachments: [{ name: 'a.mp4', path: 'uploads/req/r1/video_0-a.mp4', size: 1, kind: 'video' }],
  reviewReason: null, revisionNote: null, reviewRound: 0, submissionCount: 0,
  approvedVersion: null, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...over,
});

async function seed(reqData) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'roles', REQ), { role: 'requester' });
    await setDoc(doc(d, 'roles', OTHER), { role: 'requester' });
    await setDoc(doc(d, 'roles', ED), { role: 'editor' });
    await setDoc(doc(d, 'roles', ED2), { role: 'editor' });
    await setDoc(doc(d, 'roles', STAFF), { role: 'staff' });
    await setDoc(doc(d, 'roles', MGR), { role: 'staff', manager: true });
    await setDoc(doc(d, 'users', NOROLE), { email: 'n@x.y' });
    if (reqData) await setDoc(doc(d, 'requests', 'r1'), { ...reqData, createdAt: new Date(), updatedAt: new Date() });
  });
}
beforeEach(async () => { ctxs.clear(); await env.clearFirestore(); await env.clearStorage(); });

const note = (type, extra) => ({
  requestId: 'r1', type, message: 'm', audience: 'user', actorId: '', createdAt: serverTimestamp(), ...extra,
});

test('役割: 自分の役割は読めるが書き換えられない（昇格不可）', async () => {
  await seed();
  await assertSucceeds(getDoc(doc(db(REQ), 'roles', REQ)));
  await assertFails(getDoc(doc(db(REQ), 'roles', ED)));
  await assertFails(setDoc(doc(db(REQ), 'roles', REQ), { role: 'editor' }));
  await assertFails(setDoc(doc(db(NOROLE), 'roles', NOROLE), { role: 'editor' }));
  await assertFails(setDoc(doc(db(REQ), 'users', REQ), { role: 'editor' }));
  await assertSucceeds(setDoc(doc(db(REQ), 'users', REQ), { email: 'a@b.c' }));
});

test('依頼作成: 依頼者のみ・新規依頼通知と同時', async () => {
  await seed();
  const b = writeBatch(db(REQ));
  b.set(doc(db(REQ), 'requests', 'r1'), newReq());
  b.set(doc(db(REQ), 'notifications', 'r1_new'), note('newRequest', { audience: 'editors', recipientId: null, actorId: REQ }));
  await assertSucceeds(b.commit());
  // 編集者は作成不可、役割なしも不可
  await assertFails(setDoc(doc(db(ED), 'requests', 'r2'), newReq({ requesterId: ED })));
  await assertFails(setDoc(doc(db(NOROLE), 'requests', 'r3'), newReq({ requesterId: NOROLE })));
  // 他人名義・最初から編集中・添付なしは不可
  await assertFails(setDoc(doc(db(REQ), 'requests', 'r4'), newReq({ requesterId: OTHER })));
  await assertFails(setDoc(doc(db(REQ), 'requests', 'r5'), newReq({ status: 'editing' })));
  await assertFails(setDoc(doc(db(REQ), 'requests', 'r6'), newReq({ attachments: [] })));
});

test('閲覧: 登録済みスタッフは全案件を閲覧できる。承認前（役割なし）は不可', async () => {
  await seed(newReq());
  await assertSucceeds(getDoc(doc(db(REQ), 'requests', 'r1')));
  await assertSucceeds(getDoc(doc(db(ED), 'requests', 'r1')));
  await assertSucceeds(getDoc(doc(db(OTHER), 'requests', 'r1'))); // 別の依頼者も閲覧可
  await assertFails(getDoc(doc(db(NOROLE), 'requests', 'r1')));
  await seed(newReq({ editorId: ED, status: 'editing' }));
  await assertSucceeds(getDoc(doc(db(ED), 'requests', 'r1')));
  await assertSucceeds(getDoc(doc(db(ED2), 'requests', 'r1'))); // 担当外の編集者も閲覧可
  await assertSucceeds(getDocs(collection(db(OTHER), 'requests')));
  await assertFails(getDocs(collection(db(NOROLE), 'requests')));
  await assertSucceeds(getDocs(query(collection(db(REQ), 'requests'), where('requesterId', '==', REQ))));
});

test('編集開始: 編集者のみ・自分を担当にする', async () => {
  await seed(newReq());
  await assertFails(updateDoc(doc(db(REQ), 'requests', 'r1'), { status: 'editing', editorId: REQ, updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db(ED), 'requests', 'r1'), { status: 'editing', editorId: ED2, updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db(ED), 'requests', 'r1'), { status: 'editing', editorId: ED, title: 'x', updatedAt: serverTimestamp() }));
  // 編集担当の名前（編集を開始した編集者のログイン名）も一緒に保存できる。
  await assertFails(updateDoc(doc(db(ED), 'requests', 'r1'), { status: 'editing', editorId: ED, editorName: 'x', approvedVersion: 1, updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(db(ED), 'requests', 'r1'), { status: 'editing', editorId: ED, editorName: '山田', updatedAt: serverTimestamp() }));
  // 他の編集者はもう開始できない
  await assertFails(updateDoc(doc(db(ED2), 'requests', 'r1'), { status: 'needsInfo', editorId: ED2, reviewReason: 'x', reviewRound: 1, updatedAt: serverTimestamp() }));
});

test('受付待ちに戻った依頼の再開は、担当の編集者だけ', async () => {
  await seed(newReq({ editorId: ED, status: 'pending' }));
  const upd = { status: 'editing', updatedAt: serverTimestamp() };
  await assertFails(updateDoc(doc(db(ED2), 'requests', 'r1'), { ...upd, editorId: ED2 }));
  await assertFails(updateDoc(doc(db(ED2), 'requests', 'r1'), { status: 'needsInfo', editorId: ED2, reviewReason: 'x', reviewRound: 1, updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(db(ED), 'requests', 'r1'), { ...upd, editorId: ED }));
});

test('要確認: 理由必須・通知は相手宛て。再送信は依頼者のみ', async () => {
  await seed(newReq());
  const upd = { status: 'needsInfo', reviewReason: '', reviewRound: 1, inquirerIds: [ED], updatedAt: serverTimestamp() };
  await assertFails(updateDoc(doc(db(ED), 'requests', 'r1'), upd));
  const b = writeBatch(db(ED));
  b.update(doc(db(ED), 'requests', 'r1'), { ...upd, reviewReason: '尺が不明' });
  b.set(doc(db(ED), 'notifications', 'r1_needsinfo_1'), note('needsInfo', { recipientId: REQ, actorId: ED }));
  await assertSucceeds(b.commit());
  // 問合せは担当の決定ではない（担当は変わらない）。担当を名乗る更新は不可。
  assert.equal((await getDoc(doc(db(ED), 'requests', 'r1'))).data().editorId, null);
  // 担当がいない間は、別の編集者も続けて問い合わせられる（履歴は同時に積む）。
  await assertFails(updateDoc(doc(db(ED2), 'requests', 'r1'), { status: 'needsInfo', editorId: ED2, reviewReason: 'y', reviewRound: 2, inquirerIds: [ED, ED2], updatedAt: serverTimestamp() }));
  const b2 = writeBatch(db(ED2));
  b2.update(doc(db(ED2), 'requests', 'r1'), { status: 'needsInfo', reviewReason: '字幕は？', reviewRound: 2, inquirerIds: [ED, ED2], updatedAt: serverTimestamp() });
  b2.set(doc(db(ED2), 'notifications', 'r1_needsinfo_2'), note('needsInfo', { recipientId: REQ, actorId: ED2 }));
  b2.set(doc(db(ED2), 'requests', 'r1', 'inquiries', 'r2'), { round: 2, question: '字幕は？', editorId: ED2, editorName: 'B', askedAt: serverTimestamp(), answer: null, answeredAt: null });
  await assertSucceeds(b2.commit());
  // 依頼者以外は再送信不可
  await assertFails(updateDoc(doc(db(OTHER), 'requests', 'r1'), { status: 'pending', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db(ED), 'requests', 'r1'), { status: 'pending', updatedAt: serverTimestamp() }));
  const r = writeBatch(db(REQ));
  r.update(doc(db(REQ), 'requests', 'r1'), { status: 'pending', title: 'n', brief, dueDate: new Date('2026-12-02'), reviewReason: null, updatedAt: serverTimestamp() });
  r.set(doc(db(REQ), 'notifications', 'r1_resubmit_1'), note('resubmitted', { recipientId: ED, actorId: REQ }));
  await assertSucceeds(r.commit());
});

test('修正の依頼への問合せ: 担当の編集者だけが問い合わせ、依頼者の回答で修正に戻る', async () => {
  await seed(newReq({ editorId: ED, status: 'revision', revisionNote: '直して', submissionCount: 1, inquirerIds: [] }));
  const ask = { status: 'needsInfo', reviewReason: 'どこを？', reviewRound: 1, inquirerIds: [ED], inquiryFrom: 'revision', updatedAt: serverTimestamp() };
  // 担当ではない編集者は不可
  await assertFails(updateDoc(doc(db(ED2), 'requests', 'r1'), { ...ask, inquirerIds: [ED2] }));
  const a = writeBatch(db(ED));
  a.update(doc(db(ED), 'requests', 'r1'), ask);
  a.set(doc(db(ED), 'notifications', 'r1_needsinfo_1'), note('needsInfo', { recipientId: REQ, actorId: ED }));
  a.set(doc(db(ED), 'requests', 'r1', 'inquiries', 'r1'), { round: 1, question: 'どこを？', editorId: ED, editorName: 'A', askedAt: serverTimestamp(), answer: null, answeredAt: null });
  await assertSucceeds(a.commit());
  // 回答は、受付待ちではなく修正に戻る
  await assertFails(updateDoc(doc(db(REQ), 'requests', 'r1'), { status: 'pending', title: 'n', brief, dueDate: new Date('2026-12-02'), reviewReason: null, inquiryFrom: null, updatedAt: serverTimestamp() }));
  const r = writeBatch(db(REQ));
  r.update(doc(db(REQ), 'requests', 'r1'), { status: 'revision', title: 'n', brief, dueDate: new Date('2026-12-02'), reviewReason: null, inquiryFrom: null, updatedAt: serverTimestamp() });
  r.set(doc(db(REQ), 'notifications', 'r1_resubmit_1_' + ED), note('resubmitted', { recipientId: ED, actorId: REQ }));
  await assertSucceeds(r.commit());
});

test('動画の確認中: 依頼者は添付を追加だけできる（外す・他人・承認後は不可）', async () => {
  await seed(newReq({ editorId: ED, status: 'review', submissionCount: 1 }));
  const old = newReq().attachments;
  const add = { name: 'b.pdf', path: 'uploads/req/r1/reference_1-b.pdf', size: 1, kind: 'reference' };
  await assertSucceeds(updateDoc(doc(db(REQ), 'requests', 'r1'), { attachments: [...old, add], updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db(OTHER), 'requests', 'r1'), { attachments: [...old, add, add], updatedAt: serverTimestamp() }));
  // 外す（件数が増えない）ことは不可
  await assertFails(updateDoc(doc(db(REQ), 'requests', 'r1'), { attachments: [add], updatedAt: serverTimestamp() }));
  // 他の項目は同時に変えられない
  await assertFails(updateDoc(doc(db(REQ), 'requests', 'r1'), { attachments: [...old, add, add], title: 'x', updatedAt: serverTimestamp() }));
});

test('投稿済みの依頼: 依頼者本人だけが、記録ごと削除できる', async () => {
  await seed(newReq({ editorId: ED, status: 'posted', approvedVersion: 1, submissionCount: 1 }));
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'requests', 'r1', 'submissions', 'v1'), { version: 1, name: 'a.mp4', path: 'videos/r1/v1/a.mp4', size: 1, uploadedBy: ED });
  });
  await assertFails(deleteDoc(doc(db(ED), 'requests', 'r1', 'submissions', 'v1')));
  await assertFails(deleteDoc(doc(db(OTHER), 'requests', 'r1')));
  const b = writeBatch(db(REQ));
  b.delete(doc(db(REQ), 'requests', 'r1', 'submissions', 'v1'));
  b.delete(doc(db(REQ), 'requests', 'r1'));
  await assertSucceeds(b.commit());
});

test('承認済み・投稿前の依頼は、依頼者でも削除できない', async () => {
  await seed(newReq({ editorId: ED, status: 'review', approvedVersion: 1, submissionCount: 1 }));
  await assertFails(deleteDoc(doc(db(REQ), 'requests', 'r1')));
});

test('通知: 状態更新なしの単独作成・他人宛ての偽装は不可', async () => {
  await seed(newReq({ editorId: ED, status: 'editing' }));
  await assertFails(setDoc(doc(db(REQ), 'notifications', 'x'), note('approved', { recipientId: ED, actorId: REQ })));
  await assertFails(setDoc(doc(db(OTHER), 'notifications', 'y'), note('revisionRequested', { recipientId: ED, actorId: OTHER })));
});

test('提出: 提出記録と同時のみ・担当編集者のみ。承認前は投稿済にできない', async () => {
  await seed(newReq({ editorId: ED, status: 'editing' }));
  // 提出記録なしの単独更新は不可
  await assertFails(updateDoc(doc(db(ED), 'requests', 'r1'), { status: 'review', submissionCount: 1, updatedAt: serverTimestamp() }));
  const sub = (d, uid) => {
    const b = writeBatch(d);
    b.update(doc(d, 'requests', 'r1'), { status: 'review', submissionCount: 1, revisionNote: null, updatedAt: serverTimestamp() });
    b.set(doc(d, 'requests', 'r1', 'submissions', 'v1'), { version: 1, name: 'v.mp4', path: 'videos/r1/v1/v.mp4', size: 1, uploadedBy: uid, createdAt: serverTimestamp() });
    b.set(doc(d, 'notifications', 'r1_review_1'), note('reviewRequested', { recipientId: REQ, actorId: uid }));
    return b.commit();
  };
  await assertFails(sub(db(ED2), ED2));
  await assertSucceeds(sub(db(ED), ED));
  // 承認前の投稿済は不可
  await assertFails(updateDoc(doc(db(ED), 'requests', 'r1'), { status: 'posted', updatedAt: serverTimestamp() }));
  // 提出動画の閲覧: 依頼者・担当編集者のみ
  await assertSucceeds(getDoc(doc(db(REQ), 'requests', 'r1', 'submissions', 'v1')));
  await assertFails(getDoc(doc(db(OTHER), 'requests', 'r1', 'submissions', 'v1')));
});

test('修正指示・承認・投稿済', async () => {
  await seed(newReq({ editorId: ED, status: 'review', submissionCount: 1 }));
  // 承認は依頼者のみ・状態は初稿確認のまま
  await assertFails(updateDoc(doc(db(ED), 'requests', 'r1'), { approvedVersion: 1, updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db(OTHER), 'requests', 'r1'), { approvedVersion: 1, updatedAt: serverTimestamp() }));
  const ap = writeBatch(db(REQ));
  ap.update(doc(db(REQ), 'requests', 'r1'), { approvedVersion: 1, approvedAt: serverTimestamp(), updatedAt: serverTimestamp() });
  ap.set(doc(db(REQ), 'notifications', 'r1_approved'), note('approved', { recipientId: ED, actorId: REQ }));
  await assertSucceeds(ap.commit());
  // 承認後は修正指示不可、承認で自動的に投稿済にもならない
  await assertFails(updateDoc(doc(db(REQ), 'requests', 'r1'), { status: 'revision', revisionNote: 'x', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db(REQ), 'requests', 'r1'), { status: 'posted', updatedAt: serverTimestamp() }));
  // 投稿済は担当編集者のみ
  await assertFails(updateDoc(doc(db(ED2), 'requests', 'r1'), { status: 'posted', postedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(db(ED), 'requests', 'r1'), { status: 'posted', postedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
});

test('修正指示: 承認前の依頼者のみ・修正記録と通知', async () => {
  await seed(newReq({ editorId: ED, status: 'review', submissionCount: 1 }));
  const rv = (d, uid) => {
    const b = writeBatch(d);
    b.update(doc(d, 'requests', 'r1'), { status: 'revision', revisionNote: '直して', updatedAt: serverTimestamp() });
    b.set(doc(d, 'requests', 'r1', 'revisions', '1'), { version: 1, instruction: '直して', createdBy: uid, createdAt: serverTimestamp() });
    b.set(doc(d, 'notifications', 'r1_revision_1'), note('revisionRequested', { recipientId: ED, actorId: uid }));
    return b.commit();
  };
  await assertFails(rv(db(OTHER), OTHER));
  await assertFails(rv(db(ED), ED));
  await assertSucceeds(rv(db(REQ), REQ));
});

test('通知の閲覧: 宛先本人と編集者宛て一斉通知は編集者のみ', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'notifications', 'a'), { recipientId: REQ, audience: 'user', requestId: 'r1' });
    await setDoc(doc(c.firestore(), 'notifications', 'b'), { recipientId: null, audience: 'editors', requestId: 'r1' });
  });
  await assertSucceeds(getDoc(doc(db(REQ), 'notifications', 'a')));
  await assertFails(getDoc(doc(db(OTHER), 'notifications', 'a')));
  await assertSucceeds(getDoc(doc(db(ED), 'notifications', 'b')));
  await assertFails(getDoc(doc(db(REQ), 'notifications', 'b')));
});

test('Storage: 添付は依頼者本人のみ書込、動画は担当編集者のみ書込、閲覧は関係者のみ', async () => {
  await seed(newReq({ editorId: ED, status: 'editing' }));
  const bytes = new Uint8Array([1, 2, 3]);
  const mp4 = { contentType: 'video/mp4' };
  await assertSucceeds(uploadBytes(ref(st(REQ), 'uploads/req/r1/video_0-a.mp4'), bytes, mp4));
  await assertFails(uploadBytes(ref(st(OTHER), 'uploads/req/r1/video_0-a.mp4'), bytes, mp4));
  await assertFails(uploadBytes(ref(st(ED), 'uploads/ed/r1/x.mp4'), bytes, mp4)); // 編集者は添付不可
  await assertSucceeds(getBytes(ref(st(ED), 'uploads/req/r1/video_0-a.mp4')));
  await assertSucceeds(getBytes(ref(st(ED2), 'uploads/req/r1/video_0-a.mp4'))); // スタッフは全案件を閲覧可
  await assertFails(getBytes(ref(st(NOROLE), 'uploads/req/r1/video_0-a.mp4')));
  await assertSucceeds(uploadBytes(ref(st(ED), 'videos/r1/v1/v.mp4'), bytes, mp4));
  await assertFails(uploadBytes(ref(st(ED2), 'videos/r1/v1/v.mp4'), bytes, mp4));
  await assertFails(uploadBytes(ref(st(REQ), 'videos/r1/v1/v.mp4'), bytes, mp4));
  await assertSucceeds(getBytes(ref(st(REQ), 'videos/r1/v1/v.mp4')));
  await assertFails(getBytes(ref(st(NOROLE), 'videos/r1/v1/v.mp4')));
});

test('Storage: 承認後だけ、依頼者が添付素材と承認されなかった動画を削除できる', async () => {
  const bytes = new Uint8Array([1, 2, 3]);
  const mp4 = { contentType: 'video/mp4' };
  const put = async () => {
    await env.withSecurityRulesDisabled(async (c) => {
      for (const p of ['uploads/req/r1/video_0-a.mp4', 'videos/r1/v1/v.mp4', 'videos/r1/v2/v.mp4'])
        await uploadBytes(ref(c.storage(), p), bytes, mp4);
    });
  };
  // 承認前は削除できない
  await seed(newReq({ editorId: ED, status: 'review', submissionCount: 2 }));
  await put();
  await assertFails(deleteObject(ref(st(REQ), 'uploads/req/r1/video_0-a.mp4')));
  await assertFails(deleteObject(ref(st(REQ), 'videos/r1/v1/v.mp4')));
  // 承認後（v2を承認）
  await seed(newReq({ editorId: ED, status: 'review', submissionCount: 2, approvedVersion: 2 }));
  await put();
  await assertFails(deleteObject(ref(st(OTHER), 'uploads/req/r1/video_0-a.mp4'))); // 別の依頼者は不可
  await assertFails(deleteObject(ref(st(ED), 'uploads/req/r1/video_0-a.mp4'))); // 編集者は不可
  await assertSucceeds(deleteObject(ref(st(REQ), 'uploads/req/r1/video_0-a.mp4')));
  await assertSucceeds(deleteObject(ref(st(REQ), 'videos/r1/v1/v.mp4')));
  await assertFails(deleteObject(ref(st(REQ), 'videos/r1/v2/v.mp4'))); // 承認された版は消せない
});

test('スタッフ: 依頼の作成と、他人の依頼の受付（編集開始）の両方ができる', async () => {
  await seed();
  const b = writeBatch(db(STAFF));
  b.set(doc(db(STAFF), 'requests', 's1'), newReq({ requesterId: STAFF }));
  b.set(doc(db(STAFF), 'notifications', 's1_new'), note('newRequest', { requestId: 's1', audience: 'editors', recipientId: null, actorId: STAFF }));
  await assertSucceeds(b.commit());
  await assertFails(setDoc(doc(db(NOROLE), 'requests', 's2'), newReq({ requesterId: NOROLE })));
  await assertSucceeds(getDoc(doc(db(STAFF), 'requests', 's1')));
});

test('責任者: 他人の役割を付与・変更・取り消しできる。責任者以外・自分自身は不可', async () => {
  await seed();
  await assertSucceeds(setDoc(doc(db(MGR), 'roles', NOROLE), { role: 'editor', manager: false }));
  await assertSucceeds(setDoc(doc(db(MGR), 'roles', NOROLE), { role: 'staff', manager: false }));
  await assertSucceeds(deleteDoc(doc(db(MGR), 'roles', NOROLE)));
  await assertFails(setDoc(doc(db(MGR), 'roles', NOROLE), { role: 'boss', manager: false }));
  await assertFails(setDoc(doc(db(MGR), 'roles', NOROLE), { role: 'editor', manager: false, extra: 1 }));
  await assertFails(setDoc(doc(db(MGR), 'roles', MGR), { role: 'staff', manager: false })); // 自分は不可
  await assertFails(setDoc(doc(db(STAFF), 'roles', NOROLE), { role: 'staff', manager: false })); // 責任者以外
  await assertFails(setDoc(doc(db(NOROLE), 'roles', NOROLE), { role: 'staff', manager: true })); // 自己昇格
  await assertSucceeds(getDoc(doc(db(MGR), 'roles', NOROLE)));
});

test('責任者: 全アカウント（users）を読める。他の人は自分だけ', async () => {
  await seed();
  await assertSucceeds(getDocs(collection(db(MGR), 'users')));
  await assertSucceeds(getDoc(doc(db(NOROLE), 'users', NOROLE)));
  await assertFails(getDocs(collection(db(STAFF), 'users')));
});

test('招待: 責任者だけが作れる。本人は確認済みメールで、招待どおりの権限だけ自分に付けられる', async () => {
  await seed();
  const inv = { role: 'editor', manager: false, invitedBy: MGR, createdAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(db(MGR), 'invites', 'new@x.y'), inv));
  await assertFails(setDoc(doc(db(STAFF), 'invites', 'z@x.y'), { ...inv, invitedBy: STAFF }));
  const me = (uid, email, verified = true) =>
    env.authenticatedContext(uid, { email, email_verified: verified }).firestore();
  // 招待どおり → 成功。権限の水増し・責任者化・他人の招待・未確認メールは不可
  await assertFails(setDoc(doc(me('n1', 'new@x.y'), 'roles', 'n1'), { role: 'staff', manager: false }));
  await assertFails(setDoc(doc(me('n1', 'new@x.y'), 'roles', 'n1'), { role: 'editor', manager: true }));
  await assertFails(setDoc(doc(me('n1', 'other@x.y'), 'roles', 'n1'), { role: 'editor', manager: false }));
  await assertFails(setDoc(doc(me('n1', 'new@x.y', false), 'roles', 'n1'), { role: 'editor', manager: false }));
  await assertSucceeds(getDoc(doc(me('n1', 'new@x.y'), 'invites', 'new@x.y')));
  await assertFails(getDoc(doc(me('n1', 'other@x.y'), 'invites', 'new@x.y')));
  await assertSucceeds(setDoc(doc(me('n1', 'new@x.y'), 'roles', 'n1'), { role: 'editor', manager: false }));
  await assertSucceeds(deleteDoc(doc(me('n1', 'new@x.y'), 'invites', 'new@x.y')));
});

test('ライブラリへの直接追加: スタッフ本人が、投稿済みの記録・動画を作れる。他人名義・上書きは不可', async () => {
  await seed();
  const libReq = (uid, over = {}) => ({
    source: 'library', requesterId: uid, requesterName: 'n', editorId: uid, editorName: 'n', status: 'posted',
    title: 't', brief, attachments: [], reviewReason: null, revisionNote: null, reviewRound: 0,
    submissionCount: 1, approvedVersion: 1, approvedAt: new Date('2026-11-01'), postedAt: new Date('2026-11-01'),
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...over,
  });
  const sub = (uid, id, over = {}) => ({
    version: 1, name: 'a.mp4', path: `library/${uid}/${id}/a.mp4`, size: 1, uploadedBy: uid,
    createdAt: serverTimestamp(), ...over,
  });
  const add = (uid, id, req, video = sub(uid, id)) => {
    const b = writeBatch(db(uid));
    b.set(doc(db(uid), 'requests', id), req);
    if (video) b.set(doc(db(uid), 'requests', id, 'submissions', 'v1'), video);
    return b.commit();
  };
  const mp4 = { contentType: 'video/mp4' };
  const file = ref(st(STAFF), `library/${STAFF}/l1/a.mp4`);
  await assertFails(uploadBytes(ref(st(STAFF), `library/${REQ}/l1/a.mp4`), new Uint8Array(1), mp4));
  await assertFails(uploadBytes(ref(st(NOROLE), `library/${NOROLE}/l1/a.mp4`), new Uint8Array(1), mp4));
  await assertFails(uploadBytes(ref(st(STAFF), `library/${STAFF}/l1/a.pdf`), new Uint8Array(1), { contentType: 'application/pdf' }));
  await assertSucceeds(uploadBytes(file, new Uint8Array(1), mp4));
  await assertSucceeds(uploadBytes(ref(st(STAFF), `library/${STAFF}/l1/thumb.jpg`), new Uint8Array(1), { contentType: 'image/jpeg' }));

  await assertFails(add(NOROLE, 'l0', libReq(NOROLE)));
  await assertFails(add(STAFF, 'l2', libReq(REQ)));
  await assertFails(add(STAFF, 'l2', libReq(STAFF), null)); // 動画の記録なし
  await assertFails(add(STAFF, 'l2', libReq(STAFF, { status: 'review' })));
  await assertFails(add(STAFF, 'l2', libReq(STAFF, { title: '' })));
  await assertFails(add(STAFF, 'l2', libReq(STAFF, { extra: 1 })));
  await assertFails(add(STAFF, 'l2', libReq(STAFF), sub(STAFF, 'l2', { path: 'videos/l2/v1/a.mp4' })));
  await assertSucceeds(add(STAFF, 'l1', libReq(STAFF)));

  await assertFails(uploadBytes(file, new Uint8Array(2), mp4)); // 記録のあとは上書き不可
  await assertSucceeds(getBytes(ref(st(ED), `library/${STAFF}/l1/a.mp4`)));
  await assertFails(getBytes(ref(st(NOROLE), `library/${STAFF}/l1/a.mp4`)));
  await assertFails(deleteDoc(doc(db(REQ), 'requests', 'l1')));
  await assertFails(deleteObject(ref(st(REQ), `library/${STAFF}/l1/a.mp4`)));
  await assertSucceeds(deleteObject(file));
  const b = writeBatch(db(STAFF));
  b.delete(doc(db(STAFF), 'requests', 'l1', 'submissions', 'v1'));
  b.delete(doc(db(STAFF), 'requests', 'l1'));
  await assertSucceeds(b.commit());
});
