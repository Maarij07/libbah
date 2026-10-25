package com.labbiah.labbiah

fun main() {
    var delivered = 0
    val oldActivity: (Map<String, Any?>?) -> Unit = {}
    val newActivity: (Map<String, Any?>?) -> Unit = { delivered++ }
    CallCenter.attachListener(oldActivity)
    CallCenter.attachListener(newActivity)
    CallCenter.detachListener(oldActivity)
    CallCenter.notifyEnded()
    check(delivered == 1) { "Old activity cleanup removed the current listener" }
    CallCenter.detachListener(newActivity)
    CallCenter.notifyEnded()
    check(delivered == 1) { "Detached listener still received updates" }
    CallCenter.attachListener(newActivity)
    CallCenter.notifyEnded()
    check(delivered == 2) { "Reattached listener did not receive updates" }
    println("Native call listener regression passed")
}
