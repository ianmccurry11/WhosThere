package com.whosthere.app.model

import com.google.firebase.firestore.DocumentId

data class User(
    @DocumentId val id: String = "",
    val displayName: String = "",
    val email: String? = null,
    val joinedGroupIds: List<String> = emptyList(),
    val favoriteGroupIds: List<String> = emptyList(),
    val createdAt: com.google.firebase.Timestamp = com.google.firebase.Timestamp.now(),
    val autoCheckOutMinutes: Int = 60,
    val discriminator: String = "0000",
    val usernameTag: String = "",
    val fcmToken: String? = null,
    val isPremium: Boolean = false,
    val profileEmoji: String? = null,
    val profileColor: String? = null,
    val totalXP: Int = 0,
    val level: Int = 1
) {
    val fullUsername: String get() = "$displayName#$discriminator"
    val needsDiscriminatorMigration: Boolean get() = discriminator == "XXXX" || discriminator == "0000" || usernameTag.isEmpty()
    val hasDefaultName: Boolean get() {
        val name = displayName.trim()
        return when {
            name.startsWith("Player ") && name.length <= 11 -> true
            name.startsWith("User ") && name.length <= 9 -> true
            name == "User" -> true
            name.length < 2 -> true
            else -> false
        }
    }
}
