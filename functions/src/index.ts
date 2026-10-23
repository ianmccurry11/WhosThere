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

import * as functions from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Types
interface NotificationPreferences {
  arrivals: boolean;
  departures: boolean;
  messages: boolean;
  muted: boolean;
}

interface User {
  displayName: string;
  fcmToken?: string;
}

interface LocationGroup {
  name: string;
  emoji?: string;
  memberIds: string[];
}

interface Presence {
  userId: string;
  groupId: string;
  isPresent: boolean;
  displayName?: string;
  lastUpdated: admin.firestore.Timestamp;
}

interface Message {
  senderId: string;
  senderName: string;
  content: string;
  groupId: string;
  createdAt: admin.firestore.Timestamp;
}

/**
 * Get notification preferences for a user and group
 */
async function getNotificationPrefs(
  userId: string,
  groupId: string
): Promise<NotificationPreferences | null> {
  try {
    const doc = await db
      .collection("users")
      .doc(userId)
      .collection("notificationPreferences")
      .doc(groupId)
      .get();

    if (doc.exists) {
      return doc.data() as NotificationPreferences;
    }

    // Return default preferences if none set
    return {
      arrivals: true,
      departures: false,
      messages: true,
      muted: false,
    };
  } catch (error) {
    console.error("Error fetching notification prefs:", error);
    return null;
  }
}

/**
 * Get FCM tokens for group members who should receive the notification
 */
async function getTargetTokens(
  groupId: string,
  excludeUserId: string,
  notificationType: "arrivals" | "departures" | "messages"
): Promise<string[]> {
  try {
    // Get group to find member IDs
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
      console.log("Group not found:", groupId);
      return [];
    }

    const group = groupDoc.data() as LocationGroup;
    const memberIds = group.memberIds.filter((id) => id !== excludeUserId);

    const tokens: string[] = [];

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
        const user = userDoc.data() as User;
        if (user.fcmToken) {
          tokens.push(user.fcmToken);
        }
      }
    }

    return tokens;
  } catch (error) {
    console.error("Error getting target tokens:", error);
    return [];
  }
}

/**
 * Triggered when presence document is created or updated
 */
export const onPresenceChange = functions.firestore
  .document("presence/{groupId}/members/{userId}")
  .onWrite(async (change, context) => {
    const { groupId, userId } = context.params;

    // Get before and after states
    const beforeData = change.before.exists
      ? (change.before.data() as Presence)
      : null;
    const afterData = change.after.exists
      ? (change.after.data() as Presence)
      : null;

    // Determine if this is an arrival or departure
    const wasPresent = beforeData?.isPresent ?? false;
    const isPresent = afterData?.isPresent ?? false;

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
    const group = groupDoc.data() as LocationGroup;

    // Get user display name
    const displayName =
      afterData?.displayName || beforeData?.displayName || "Someone";

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

    const message: admin.messaging.MulticastMessage = {
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
      console.log(
        `Sent ${notificationType} notifications: ${response.successCount} success, ${response.failureCount} failures`
      );

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        await cleanupInvalidTokens(tokens, response.responses);
      }

      return response;
    } catch (error) {
      console.error("Error sending presence notification:", error);
      return null;
    }
  });

/**
 * Triggered when a new message is created in a group chat
 */
export const onNewMessage = functions.firestore
  .document("messages/{groupId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const { groupId } = context.params;
    const message = snapshot.data() as Message;

    // Get group info
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
      console.log("Group not found for message notification:", groupId);
      return null;
    }
    const group = groupDoc.data() as LocationGroup;

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

    const fcmMessage: admin.messaging.MulticastMessage = {
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
      console.log(
        `Sent message notifications: ${response.successCount} success, ${response.failureCount} failures`
      );

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        await cleanupInvalidTokens(tokens, response.responses);
      }

      return response;
    } catch (error) {
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

interface PresenceDoc {
  userId: string;
  isPresent: boolean;
  isManual?: boolean;
  lastUpdated?: admin.firestore.Timestamp;
  expiresAt?: admin.firestore.Timestamp;
  lastRecheckSentAt?: admin.firestore.Timestamp;
}

/**
 * Whether a check-in should no longer count (mirrors Presence.isActive)
 */
function isLapsed(data: PresenceDoc, nowMs: number): boolean {
  if (!data.isPresent) return false;
  if (data.expiresAt && data.expiresAt.toMillis() <= nowMs) return true;
  const updatedMs = data.lastUpdated?.toMillis() ?? 0;
  return nowMs - updatedMs > MAX_PRESENCE_AGE_MS;
}

/**
 * Whether a check-in is due for a silent "are you still there?" push
 */
function needsRecheck(
  data: PresenceDoc,
  nowMs: number,
  confirmedWithinMs: number
): boolean {
  if (!data.isPresent || data.isManual || isLapsed(data, nowMs)) {
    return false;
  }
  const updatedMs = data.lastUpdated?.toMillis() ?? 0;
  const lastRecheckMs = data.lastRecheckSentAt?.toMillis() ?? 0;
  return nowMs - updatedMs > confirmedWithinMs &&
    nowMs - lastRecheckMs > RECHECK_COOLDOWN_MS;
}

/**
 * True for docs at presence/{groupId}/members/{userId}
 */
function isPresenceMemberDoc(ref: admin.firestore.DocumentReference): boolean {
  return ref.parent.parent?.parent.id === "presence";
}

/**
 * Checks a presence out, re-reading it first so a heartbeat that landed
 * after the query isn't overwritten. Fires onPresenceChange ("X left").
 */
async function checkOutIfLapsed(
  ref: admin.firestore.DocumentReference
): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() as PresenceDoc | undefined;
    if (!data || !isLapsed(data, Date.now())) return false;
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
async function sendRechecks(
  docs: admin.firestore.QueryDocumentSnapshot[]
): Promise<void> {
  if (docs.length === 0) return;

  const docsByUser = new Map<string, admin.firestore.QueryDocumentSnapshot[]>();
  for (const doc of docs) {
    const userId = (doc.data() as PresenceDoc).userId;
    docsByUser.set(userId, [...(docsByUser.get(userId) ?? []), doc]);
  }

  const tokens: string[] = [];
  for (const userId of docsByUser.keys()) {
    const userDoc = await db.collection("users").doc(userId).get();
    const token = (userDoc.data() as User | undefined)?.fcmToken;
    if (token) tokens.push(token);
  }

  if (tokens.length > 0) {
    const messages: admin.messaging.Message[] = tokens.map((token) => ({
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
    console.log(
      `Sent presence re-checks: ${response.successCount} success, ` +
      `${response.failureCount} failures`
    );
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
export const presenceSweep = onSchedule(
  {
    schedule: "every 10 minutes",
    timeZone: "America/New_York",
  },
  async () => {
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
        .where(
          "lastUpdated",
          "<",
          admin.firestore.Timestamp.fromMillis(nowMs - MAX_PRESENCE_AGE_MS)
        )
        .get(),
    ]);

    const lapsedRefs = new Map<string, admin.firestore.DocumentReference>();
    for (const doc of [...expired.docs, ...old.docs]) {
      if (isPresenceMemberDoc(doc.ref)) lapsedRefs.set(doc.ref.path, doc.ref);
    }

    let checkedOut = 0;
    for (const ref of lapsedRefs.values()) {
      try {
        if (await checkOutIfLapsed(ref)) checkedOut++;
      } catch (error) {
        console.error("Error checking out lapsed presence:", ref.path, error);
      }
    }

    // 2. Quiet: still active but not confirmed recently
    const quiet = await members
      .where("isPresent", "==", true)
      .where(
        "lastUpdated",
        "<",
        admin.firestore.Timestamp.fromMillis(nowMs - SCHEDULED_RECHECK_AFTER_MS)
      )
      .get();
    const due = quiet.docs.filter((doc) =>
      isPresenceMemberDoc(doc.ref) &&
      !lapsedRefs.has(doc.ref.path) &&
      needsRecheck(doc.data() as PresenceDoc, nowMs, SCHEDULED_RECHECK_AFTER_MS)
    );
    await sendRechecks(due);

    console.log(
      `Presence sweep: checked out ${checkedOut}, re-check sent for ${due.length}`
    );
  }
);

/**
 * Someone opened a group: nudge members there whose phones have been quiet.
 * The app writes presenceRecheckRequests/{groupId} (rate-limited per check-in
 * by RECHECK_COOLDOWN_MS, so repeated opens can't spam anyone).
 */
export const onPresenceRecheckRequest = functions.firestore
  .document("presenceRecheckRequests/{groupId}")
  .onWrite(async (change, context) => {
    const { groupId } = context.params;
    const request = change.after.data() as { requestedBy?: string } | undefined;
    const requestedBy = request?.requestedBy;
    if (!requestedBy) return null;

    // Only members (or anyone, for public groups) can trigger re-checks
    const groupDoc = await db.collection("groups").doc(groupId).get();
    const group = groupDoc.data() as
      (LocationGroup & { isPublic?: boolean }) | undefined;
    if (!group) return null;
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
      const data = doc.data() as PresenceDoc;
      return data.userId !== requestedBy &&
        needsRecheck(data, nowMs, ON_DEMAND_RECHECK_AFTER_MS);
    });

    await sendRechecks(due);
    return null;
  });

/**
 * Clean up invalid FCM tokens from the database
 */
async function cleanupInvalidTokens(
  tokens: string[],
  responses: admin.messaging.SendResponse[]
): Promise<void> {
  const invalidTokens: string[] = [];

  responses.forEach((response, index) => {
    if (!response.success) {
      const errorCode = response.error?.code;
      if (
        errorCode === "messaging/invalid-registration-token" ||
        errorCode === "messaging/registration-token-not-registered"
      ) {
        invalidTokens.push(tokens[index]);
      }
    }
  });

  if (invalidTokens.length === 0) return;

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
    } catch (error) {
      console.error("Error cleaning up token:", error);
    }
  }
}
