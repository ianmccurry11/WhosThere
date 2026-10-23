//
//  ProfanityList.swift
//  WhosThereios
//
//  Blocked words for content moderation.
//  This list catches common slurs, profanity, and inappropriate terms.
//  The Validation.normalizeProfanity() function also handles common
//  character substitutions (@ -> a, $ -> s, etc.) and repeated characters.
//

import Foundation

enum ProfanityList {
    /// Blocked words — checked as whole-word matches (word boundaries)
    /// so "class" won't match "ass", "grape" won't match "rape", etc.
    static let words: Set<String> = [
        // Profanity
        "fuck", "shit", "damn", "hell", "ass", "bitch",
        "bastard", "dick", "cock", "pussy", "cunt",
        "piss", "crap", "slut", "whore", "douche",
        "wanker", "twat", "bollocks", "arsehole", "asshole",
        "motherfucker", "bullshit", "horseshit", "dipshit",
        "shithead", "fuckface", "fuckhead", "dickhead",
        "dumbass", "jackass", "fatass", "smartass", "badass",

        // Slurs — racial/ethnic
        "nigger", "nigga", "chink", "gook", "spic",
        "wetback", "kike", "beaner", "cracker",
        "honky", "gringo", "redskin", "raghead",
        "towelhead", "sandnigger", "coon", "darkie",
        "chinaman", "jap", "paki",

        // Slurs — LGBTQ+
        "fag", "faggot", "dyke", "tranny",
        "shemale", "ladyboy",

        // Slurs — disability
        "retard", "retarded", "spaz", "spastic",
        "cripple",

        // Sexual
        "penis", "vagina", "boobs", "tits",
        "dildo", "blowjob", "handjob", "cumshot",
        "orgasm", "anal", "porn", "hentai",
        "milf", "boner",

        // Violence/hate
        "nazi", "hitler", "kkk", "jihad",
        "terrorist", "genocide", "killall",

        // Drug references (contextually inappropriate for a location app)
        "cocaine", "heroin", "meth",

        // Common compound bypass attempts
        "stfu", "gtfo", "lmfao", "wtf",
    ]
}
