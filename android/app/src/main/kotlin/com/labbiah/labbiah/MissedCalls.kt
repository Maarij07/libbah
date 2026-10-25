package com.labbiah.labbiah

import android.content.Context
import android.provider.CallLog

/**
 * The people who rang and weren't answered, read from the phone's own
 * call history — one entry per caller, with how many times they tried.
 *
 * A caller stays on the list until the two of them have actually spoken:
 * only missed calls *since the last connected call* with that number
 * count. So ringing someone back and getting through clears them, without
 * Labbiah ever having to edit the call history, while a call back that
 * nobody picks up leaves them listed to try again.
 */
object MissedCalls {

    /** Newest caller first. Throws [SecurityException] without call
     * history access. */
    fun query(context: Context): List<Map<String, Any?>> {
        val columns = arrayOf(
            CallLog.Calls.NUMBER,
            CallLog.Calls.TYPE,
            CallLog.Calls.DATE,
            CallLog.Calls.DURATION,
        )
        val since = System.currentTimeMillis() - WINDOW_MILLIS
        val callers = LinkedHashMap<String, Caller>()
        val spokenSince = HashSet<String>()

        context.contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            columns,
            "${CallLog.Calls.DATE} > ?",
            arrayOf(since.toString()),
            "${CallLog.Calls.DATE} DESC",
        )?.use { cursor ->
            // Newest first, so a connected call closes off everything
            // older than it for that number.
            while (cursor.moveToNext()) {
                val number = cursor.getString(0).orEmpty()
                val key = keyOf(number)
                if (key in spokenSince) continue
                if (cursor.getInt(1) == CallLog.Calls.MISSED_TYPE) {
                    callers.getOrPut(key) { Caller(number, cursor.getLong(2)) }.count++
                } else if (cursor.getLong(3) > 0) {
                    spokenSince.add(key)
                }
            }
        }

        return callers.values.map { caller ->
            val contact = ContactLookup.find(context, caller.number, thumbnail = true)
            mapOf(
                "number" to caller.number,
                "name" to contact.name,
                "photo" to contact.photo,
                "count" to caller.count,
                "lastAt" to caller.lastAt,
            )
        }
    }

    /** The same person's number is logged with or without a country
     * code, spaces or dashes; the trailing digits identify them. */
    private fun keyOf(number: String): String =
        number.filter { it.isDigit() }.takeLast(9)

    private class Caller(val number: String, val lastAt: Long) {
        var count = 0
    }

    /** Older than this, a missed call is history rather than news. */
    private const val WINDOW_MILLIS = 30L * 24 * 60 * 60 * 1000
}
