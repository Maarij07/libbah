package com.labbiah.labbiah

import android.content.Context
import android.net.Uri
import android.provider.ContactsContract

/**
 * Finds the saved contact behind a phone number — the name and picture
 * shown for a caller ([CallCenter]) and for a missed call ([MissedCalls]).
 */
object ContactLookup {

    class Match(val name: String?, val photo: ByteArray?)

    /**
     * The contact saved for [number], matched by Android itself so that
     * spacing, dashes and country codes don't matter. [thumbnail] asks for
     * the small picture, for lists, instead of the full-size one.
     */
    fun find(context: Context, number: String, thumbnail: Boolean = false): Match {
        if (number.isEmpty()) return Match(null, null)
        val uri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
            Uri.encode(number),
        )
        val photoColumn = if (thumbnail) {
            ContactsContract.PhoneLookup.PHOTO_THUMBNAIL_URI
        } else {
            ContactsContract.PhoneLookup.PHOTO_URI
        }
        val columns = arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME, photoColumn)
        try {
            context.contentResolver.query(uri, columns, null, null, null)?.use { cursor ->
                if (!cursor.moveToFirst()) return Match(null, null)
                val name = cursor.getString(0)
                val photo = cursor.getString(1)?.let { photoUri ->
                    context.contentResolver.openInputStream(Uri.parse(photoUri))
                        ?.use { it.readBytes() }
                }
                return Match(name, photo)
            }
        } catch (_: SecurityException) {
            // No contacts access: the number alone is shown.
        } catch (_: java.io.IOException) {
            // Unreadable photo: the name alone is shown.
        }
        return Match(null, null)
    }
}
