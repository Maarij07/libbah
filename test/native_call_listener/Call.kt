package android.telecom
class Call {
    val state = STATE_ACTIVE
    val details: Details? = null
    class Details { val handle: Handle? = null; val callerDisplayName: String? = null; val connectTimeMillis = 0L }
    class Handle { val schemeSpecificPart = "" }
    companion object { const val STATE_RINGING = 2; const val STATE_ACTIVE = 4; const val STATE_HOLDING = 3; const val STATE_DISCONNECTED = 7; const val STATE_DISCONNECTING = 10 }
}
