//
//  FBLoginEvent.java
//  Facebook-v4a Plugin
//
//  Copyright (c) 2015 Corona Labs Inc. All rights reserved.
//

package plugin.facebook.v4a;

import com.ansca.corona.CoronaRuntime;

import com.naef.jnlua.LuaState;

public class FBLoginEvent extends FBBaseEvent {
	public enum Phase {
		login,
		loginFailed,
		loginCancelled,
		logout
	}

	private final long mExpirationTime;
	private final String mToken;
	private final Phase mPhase;

	public FBLoginEvent(String token, long expirationTime) {
		super(FBType.session);
		mPhase = Phase.login;
		mToken = token;
		mExpirationTime = expirationTime;
	}

	public FBLoginEvent(Phase phase) {
		super(FBType.session);
		mPhase = phase;
		mToken = null;
		mExpirationTime = 0;
	}

	public FBLoginEvent(Phase phase, String errorMessage) {
		super(FBType.session, errorMessage, true);
		mPhase = phase;
		mToken = null;
		mExpirationTime = 0;
	}

	public void executeUsing(CoronaRuntime runtime) {
		super.executeUsing(runtime);

		LuaState L = runtime.getLuaState();

		L.pushString(mPhase.name());
		L.setField(-2, "phase");

		if (mToken != null) {
			L.pushString(mToken);
			L.setField(-2, "token");

			L.pushNumber(Long.valueOf(mExpirationTime).doubleValue());
			L.setField(-2, "expiration");
		}
	}
}
