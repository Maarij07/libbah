package com.labbiah.labbiah
import android.content.Context
object ContactLookup { class Match(val name: String?, val photo: ByteArray?); fun find(context: Context, number: String) = Match(null, null) }
