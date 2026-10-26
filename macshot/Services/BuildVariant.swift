enum BuildVariant {
    #if OFFLINE
    static let isOffline = true
    static let displayName = "Macshot Studio"
    #else
    static let isOffline = false
    static let displayName = "Macshot Studio"
    #endif
}
