/**
 * Cloud Functions for Who's There app
 *
 * Handles push notifications for:
 * - Presence changes (arrivals/departures)
 * - New messages in group chat
 */

import * as functions from "firebase-functions";
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
