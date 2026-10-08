"use strict";
/**
 * Cloud Functions for Who's There app
 *
 * Handles push notifications for:
 * - Presence changes (arrivals/departures)
 * - New messages in group chat
 *
 * And presence upkeep:
 * - Checking out lapsed presences every 10 minutes
 * - Silent "re-check" pushes to phones that have gone quiet
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.onPresenceRecheckRequest = exports.presenceSweep = exports.onNewMessage = exports.onPresenceChange = void 0;
const functions = require("firebase-functions");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
/**
 * Get notification preferences for a user and group
 */
async function getNotificationPrefs(userId, groupId) {
    try {
        const doc = await db
            .collection("users")
            .doc(userId)
            .collection("notificationPreferences")
            .doc(groupId)
            .get();
        if (doc.exists) {
            return doc.data();
        }
        // Return default preferences if none set
        return {
            arrivals: true,
            departures: false,
            messages: true,
            muted: false,
        };
    }
    catch (error) {
        console.error("Error fetching notification prefs:", error);
        return null;
    }
}
/**
 * Get FCM tokens for group members who should receive the notification
 */
async function getTargetTokens(groupId, excludeUserId, notificationType) {
    try {
        // Get group to find member IDs
        const groupDoc = await db.collection("groups").doc(groupId).get();
        if (!groupDoc.exists) {
            console.log("Group not found:", groupId);
            return [];
        }
        const group = groupDoc.data();
        const memberIds = group.memberIds.filter((id) => id !== excludeUserId);
        const tokens = [];
        // For each member, check preferences and get token
        for (const memberId of memberIds) {
            // Get notification preferences
            const prefs = await getNotificationPrefs(memberId, groupId);
            if (!prefs || prefs.muted || !prefs[notificationType]) {
                continue;
            }
            // Get user's FCM token
            const userDoc = await db.collection("users").doc(memberId).get();
            if (userDoc.exists) {
                const user = userDoc.data();
                if (user.fcmToken) {
                    tokens.push(user.fcmToken);
                }
            }
        }
        return tokens;
    }
    catch (error) {
        console.error("Error getting target tokens:", error);
        return [];
    }
}
/**
 * Triggered when presence document is created or updated
 */
exports.onPresenceChange = functions.firestore
    .document("presence/{groupId}/members/{userId}")
    .onWrite(async (change, context) => {
    var _a, _b;
    const { groupId, userId } = context.params;
    // Get before and after states
    const beforeData = change.before.exists
        ? change.before.data()
        : null;
    const afterData = change.after.exists
        ? change.after.data()
        : null;
    // Determine if this is an arrival or departure
    const wasPresent = (_a = beforeData === null || beforeData === void 0 ? void 0 : beforeData.isPresent) !== null && _a !== void 0 ? _a : false;
    const isPresent = (_b = afterData === null || afterData === void 0 ? void 0 : afterData.isPresent) !== null && _b !== void 0 ? _b : false;
    // No change in presence status
    if (wasPresent === isPresent) {
        return null;
    }
    const isArrival = !wasPresent && isPresent;
    const notificationType = isArrival ? "arrivals" : "departures";
    // Get group info
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
        console.log("Group not found for presence notification:", groupId);
        return null;
    }
    const group = groupDoc.data();
    // Get user display name
    const displayName = (afterData === null || afterData === void 0 ? void 0 : afterData.displayName) || (beforeData === null || beforeData === void 0 ? void 0 : beforeData.displayName) || "Someone";
    // Get tokens for members who want this notification type
    const tokens = await getTargetTokens(groupId, userId, notificationType);
    if (tokens.length === 0) {
        console.log("No tokens to send presence notification to");
        return null;
    }
    // Build notification
    const emoji = group.emoji || "📍";
    const title = isArrival
        ? `${emoji} ${displayName} arrived!`
        : `${emoji} ${displayName} left`;
    const body = isArrival
        ? `${displayName} just checked in at ${group.name}`
        : `${displayName} left ${group.name}`;
    const message = {
        tokens,
        notification: {
            title,
            body,
        },
        data: {
            type: notificationType,
            groupId,
            userId,
        },
        apns: {
            payload: {
                aps: {
                    sound: "default",
                    badge: 1,
                },
            },
        },
    };
    // Send notifications
    try {
        const response = await messaging.sendEachForMulticast(message);
        console.log(`Sent ${notificationType} notifications: ${response.successCount} success, ${response.failureCount} failures`);
        // Clean up invalid tokens
        if (response.failureCount > 0) {
            await cleanupInvalidTokens(tokens, response.responses);
        }
        return response;
    }
    catch (error) {
        console.error("Error sending presence notification:", error);
        return null;
    }
});
/**
 * Triggered when a new message is created in a group chat
 */
exports.onNewMessage = functions.firestore
    .document("messages/{groupId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
    const { groupId } = context.params;
    const message = snapshot.data();
    // Get group info
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
        console.log("Group not found for message notification:", groupId);
        return null;
    }
    const group = groupDoc.data();
    // Get tokens for members who want message notifications (excluding sender)
    const tokens = await getTargetTokens(groupId, message.senderId, "messages");
    if (tokens.length === 0) {
        console.log("No tokens to send message notification to");
        return null;
    }
    // Build notification
    const emoji = group.emoji || "💬";
    const title = `${emoji} ${group.name}`;
    const body = `${message.senderName}: ${message.content}`;
    const fcmMessage = {
        tokens,
        notification: {
            title,
            body,
        },
        data: {
            type: "message",
            groupId,
            senderId: message.senderId,
        },
        apns: {
            payload: {
                aps: {
                    sound: "default",
                    badge: 1,
                },
            },
        },
    };
    // Send notifications
    try {
        const response = await messaging.sendEachForMulticast(fcmMessage);
        console.log(`Sent message notifications: ${response.successCount} success, ${response.failureCount} failures`);
        // Clean up invalid tokens
        if (response.failureCount > 0) {
            await cleanupInvalidTokens(tokens, response.responses);
        }
        return response;
    }
    catch (error) {
        console.error("Error sending message notification:", error);
        return null;
    }
});
// ============================================
// PRESENCE EXPIRY & RE-CHECK
// ============================================
//
// Phones keep their check-in alive by rewriting `lastUpdated`/`expiresAt`
// whenever iOS wakes the app. These functions make sure nobody stays
// "here" forever when their phone goes quiet, and nudge quiet phones to
// re-confirm with a silent push. Rules mirror Presence.isActive in the app.
/** Same cap as Presence.maxAge in the app (5 hours) */
const MAX_PRESENCE_AGE_MS = 5 * 60 * 60 * 1000;
/** Scheduled sweep nudges automatic check-ins not confirmed for this long */
const SCHEDULED_RECHECK_AFTER_MS = 25 * 60 * 1000;
/** Opening a group nudges members not confirmed for this long */
const ON_DEMAND_RECHECK_AFTER_MS = 10 * 60 * 1000;
/** Never send a single check-in more than one re-check per this window */
const RECHECK_COOLDOWN_MS = 10 * 60 * 1000;
/**
 * Whether a check-in should no longer count (mirrors Presence.isActive)
 */
function isLapsed(data, nowMs) {
    var _a, _b;
    if (!data.isPresent)
        return false;
    if (data.expiresAt && data.expiresAt.toMillis() <= nowMs)
        return true;
    const updatedMs = (_b = (_a = data.lastUpdated) === null || _a === void 0 ? void 0 : _a.toMillis()) !== null && _b !== void 0 ? _b : 0;
    return nowMs - updatedMs > MAX_PRESENCE_AGE_MS;
}
/**
 * Whether a check-in is due for a silent "are you still there?" push
 */
function needsRecheck(data, nowMs, confirmedWithinMs) {
    var _a, _b, _c, _d;
    if (!data.isPresent || data.isManual || isLapsed(data, nowMs)) {
        return false;
    }
    const updatedMs = (_b = (_a = data.lastUpdated) === null || _a === void 0 ? void 0 : _a.toMillis()) !== null && _b !== void 0 ? _b : 0;
    const lastRecheckMs = (_d = (_c = data.lastRecheckSentAt) === null || _c === void 0 ? void 0 : _c.toMillis()) !== null && _d !== void 0 ? _d : 0;
    return nowMs - updatedMs > confirmedWithinMs &&
        nowMs - lastRecheckMs > RECHECK_COOLDOWN_MS;
}
/**
 * True for docs at presence/{groupId}/members/{userId}
 */
function isPresenceMemberDoc(ref) {
    var _a;
    return ((_a = ref.parent.parent) === null || _a === void 0 ? void 0 : _a.parent.id) === "presence";
}
/**
 * Checks a presence out, re-reading it first so a heartbeat that landed
 * after the query isn't overwritten. Fires onPresenceChange ("X left").
 */
async function checkOutIfLapsed(ref) {
    return db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const data = snap.data();
        if (!data || !isLapsed(data, Date.now()))
            return false;
        tx.update(ref, {
            isPresent: false,
            expiresAt: admin.firestore.FieldValue.delete(),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            source: "server_expiry",
        });
        return true;
    });
}
/**
 * Sends one silent push per user asking their phone to re-confirm its
 * check-ins, then stamps lastRecheckSentAt so we don't spam them.
 */
async function sendRechecks(docs) {
    var _a, _b;
    if (docs.length === 0)
        return;
    const docsByUser = new Map();
    for (const doc of docs) {
        const userId = doc.data().userId;
        docsByUser.set(userId, [...((_a = docsByUser.get(userId)) !== null && _a !== void 0 ? _a : []), doc]);
    }
    const tokens = [];
    for (const userId of docsByUser.keys()) {
        const userDoc = await db.collection("users").doc(userId).get();
        const token = (_b = userDoc.data()) === null || _b === void 0 ? void 0 : _b.fcmToken;
        if (token)
            tokens.push(token);
    }
    if (tokens.length > 0) {
        const messages = tokens.map((token) => ({
            token,
            data: { type: "presenceRecheck" },
            apns: {
                headers: {
                    "apns-push-type": "background",
                    "apns-priority": "5",
                },
                payload: { aps: { contentAvailable: true } },
            },
        }));
        const response = await messaging.sendEach(messages);
        console.log(`Sent presence re-checks: ${response.successCount} success, ` +
            `${response.failureCount} failures`);
        if (response.failureCount > 0) {
            await cleanupInvalidTokens(tokens, response.responses);
        }
    }
    const batch = db.batch();
    for (const doc of docs) {
        batch.update(doc.ref, {
            lastRecheckSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    await batch.commit();
}
/**
 * Every 10 minutes: check out lapsed presences and nudge quiet phones.
 * Replaces the old nightly cleanup, whose query had no index to run on.
 */
exports.presenceSweep = (0, scheduler_1.onSchedule)({
    schedule: "every 10 minutes",
    timeZone: "America/New_York",
}, async () => {
    const nowMs = Date.now();
    const now = admin.firestore.Timestamp.fromMillis(nowMs);
    const members = db.collectionGroup("members");
    // 1. Lapsed: past expiresAt, or not updated in 5 hours
    const [expired, old] = await Promise.all([
        members
            .where("isPresent", "==", true)
            .where("expiresAt", "<", now)
            .get(),
        members
            .where("isPresent", "==", true)
            .where("lastUpdated", "<", admin.firestore.Timestamp.fromMillis(nowMs - MAX_PRESENCE_AGE_MS))
            .get(),
    ]);
    const lapsedRefs = new Map();
    for (const doc of [...expired.docs, ...old.docs]) {
        if (isPresenceMemberDoc(doc.ref))
            lapsedRefs.set(doc.ref.path, doc.ref);
    }
    let checkedOut = 0;
    for (const ref of lapsedRefs.values()) {
        try {
            if (await checkOutIfLapsed(ref))
                checkedOut++;
        }
        catch (error) {
            console.error("Error checking out lapsed presence:", ref.path, error);
        }
    }
    // 2. Quiet: still active but not confirmed recently
    const quiet = await members
        .where("isPresent", "==", true)
        .where("lastUpdated", "<", admin.firestore.Timestamp.fromMillis(nowMs - SCHEDULED_RECHECK_AFTER_MS))
        .get();
    const due = quiet.docs.filter((doc) => isPresenceMemberDoc(doc.ref) &&
        !lapsedRefs.has(doc.ref.path) &&
        needsRecheck(doc.data(), nowMs, SCHEDULED_RECHECK_AFTER_MS));
    await sendRechecks(due);
    console.log(`Presence sweep: checked out ${checkedOut}, re-check sent for ${due.length}`);
});
/**
 * Someone opened a group: nudge members there whose phones have been quiet.
 * The app writes presenceRecheckRequests/{groupId} (rate-limited per check-in
 * by RECHECK_COOLDOWN_MS, so repeated opens can't spam anyone).
 */
exports.onPresenceRecheckRequest = functions.firestore
    .document("presenceRecheckRequests/{groupId}")
    .onWrite(async (change, context) => {
    const { groupId } = context.params;
    const request = change.after.data();
    const requestedBy = request === null || request === void 0 ? void 0 : request.requestedBy;
    if (!requestedBy)
        return null;
    // Only members (or anyone, for public groups) can trigger re-checks
    const groupDoc = await db.collection("groups").doc(groupId).get();
    const group = groupDoc.data();
    if (!group)
        return null;
    if (!group.isPublic && !group.memberIds.includes(requestedBy)) {
        console.log("Ignoring re-check request from non-member:", requestedBy);
        return null;
    }
    const nowMs = Date.now();
    const present = await db
        .collection("presence")
        .doc(groupId)
        .collection("members")
        .where("isPresent", "==", true)
        .get();
    const due = present.docs.filter((doc) => {
        const data = doc.data();
        return data.userId !== requestedBy &&
            needsRecheck(data, nowMs, ON_DEMAND_RECHECK_AFTER_MS);
    });
    await sendRechecks(due);
    return null;
});
/**
 * Clean up invalid FCM tokens from the database
 */
async function cleanupInvalidTokens(tokens, responses) {
    const invalidTokens = [];
    responses.forEach((response, index) => {
        var _a;
        if (!response.success) {
            const errorCode = (_a = response.error) === null || _a === void 0 ? void 0 : _a.code;
            if (errorCode === "messaging/invalid-registration-token" ||
                errorCode === "messaging/registration-token-not-registered") {
                invalidTokens.push(tokens[index]);
            }
        }
    });
    if (invalidTokens.length === 0)
        return;
    console.log("Cleaning up invalid tokens:", invalidTokens.length);
    // Find and update users with these tokens
    for (const token of invalidTokens) {
        try {
            const usersSnapshot = await db
                .collection("users")
                .where("fcmToken", "==", token)
                .get();
            for (const userDoc of usersSnapshot.docs) {
                await userDoc.ref.update({
                    fcmToken: admin.firestore.FieldValue.delete(),
                });
                console.log("Removed invalid token from user:", userDoc.id);
            }
        }
        catch (error) {
            console.error("Error cleaning up token:", error);
        }
    }
}
//# sourceMappingURL=index.js.map