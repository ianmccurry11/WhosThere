"use strict";
/**
 * Cloud Functions for Who's There app
 *
 * Handles push notifications for:
 * - Presence changes (arrivals/departures)
 * - New messages in group chat
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.nightlyPresenceCleanup = exports.onNewMessage = exports.onPresenceChange = void 0;
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
/**
 * Nightly cleanup of stale presences at 2:00 AM EST
 * Clears any presence records where isPresent is true and lastUpdated is older than 5 hours
 */
exports.nightlyPresenceCleanup = (0, scheduler_1.onSchedule)({
    schedule: "0 2 * * *",
    timeZone: "America/New_York",
}, async () => {
    const fiveHoursAgo = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 5 * 60 * 60 * 1000));
    console.log(`Running nightly presence cleanup. Clearing presences older than ${fiveHoursAgo.toDate().toISOString()}`);
    // Get all groups
    const groupsSnapshot = await db.collection("groups").get();
    let totalCleaned = 0;
    for (const groupDoc of groupsSnapshot.docs) {
        const groupId = groupDoc.id;
        // Find stale presence records in this group
        const stalePresences = await db
            .collection("presence")
            .doc(groupId)
            .collection("members")
            .where("isPresent", "==", true)
            .where("lastUpdated", "<", fiveHoursAgo)
            .get();
        if (stalePresences.empty)
            continue;
        // Batch update stale presences to checked out
        const batch = db.batch();
        for (const doc of stalePresences.docs) {
            batch.update(doc.ref, {
                isPresent: false,
                lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        await batch.commit();
        totalCleaned += stalePresences.size;
        console.log(`Cleaned ${stalePresences.size} stale presences in group ${groupId} (${groupDoc.data().name})`);
    }
    console.log(`Nightly cleanup complete. Total stale presences cleared: ${totalCleaned}`);
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