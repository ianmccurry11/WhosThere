package com.whosthere.app.util

import android.util.Log

object AppLogger {
    private const val TAG = "WhosThere"
    fun debug(message: String) { Log.d(TAG, message) }
    fun error(message: String, throwable: Throwable? = null) { Log.e(TAG, message, throwable) }
    fun info(message: String) { Log.i(TAG, message) }
}
