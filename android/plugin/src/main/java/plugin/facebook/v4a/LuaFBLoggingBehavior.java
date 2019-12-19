//
//  LuaFBLoggingBehavior.java
//  Facebook-v4a Plugin
//
//  Copyright (c) 2015 Corona Labs Inc. All rights reserved.
//

package plugin.facebook.v4a;

public enum LuaFBLoggingBehavior {
    ACCESS_TOKENS("accessTokens"),
    APP_EVENTS("appEvents"),
    CACHE("cache"),
    GRAPH_API_DEBUG_WARNING("graphAPIDebugWarning"),
    GRAPH_API_DEBUG_INFO("graphAPIDebugInfo"),
    NETWORK_REQUESTS("networkRequests"),
    PLUGIN_AND_FACEBOOK_SDK_COMMUNICATION("pluginAndFacebookSDKCommunication");

    private final String luaName;

    LuaFBLoggingBehavior(final String luaName) {
        this.luaName = luaName;
    }

    @Override
    public String toString() {
        return luaName;
    }

    public static boolean contains(String behaviorToCheck) {
        for (LuaFBLoggingBehavior behavior : LuaFBLoggingBehavior.values()) {
            if (behavior.toString().equals(behaviorToCheck)) {
                return true;
            }
        }
        return false;
    }
}
