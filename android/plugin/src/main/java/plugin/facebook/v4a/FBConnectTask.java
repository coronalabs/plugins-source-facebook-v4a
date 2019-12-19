//
//  FBConnectTask.java
//  Facebook-v4a Plugin
//
//  Copyright (c) 2015 Corona Labs Inc. All rights reserved.
//

package plugin.facebook.v4a;

import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeTask;
import com.naef.jnlua.LuaState;

class FBConnectTask implements CoronaRuntimeTask {
	private static final int SESSION = 0;
	private static final int SESSION_ERROR= 1;
	private static final int REQUEST = 2;

	private final int myListener;
	private final int myType;
	private FBLoginEvent.Phase myPhase;
	private final String myAccessToken;
	private final long myTokenExpiration;
	private String myMsg;
	private boolean myIsError;
	private boolean myDidComplete;
	private final boolean myIsDialog;

	FBConnectTask(int listener, FBLoginEvent.Phase phase, String accessToken, long tokenExpiration)
	{
		myType = SESSION;
		myPhase = phase;
		myAccessToken = accessToken;

		// On Android, FB provides UNIX timestamp in milliseconds
		// We want it in seconds:
		myTokenExpiration = tokenExpiration / 1000;
		myListener = listener;
		myIsDialog = false;
	}

	FBConnectTask(int listener, String msg)
	{
		myType = SESSION_ERROR;
		myAccessToken = "";
		myMsg = msg;
		myTokenExpiration = 0;
		myListener = listener;
		myIsDialog = false;
	}

	FBConnectTask(int listener, String msg, boolean isError)
	{
		myType = REQUEST;
		myAccessToken = "";
		myTokenExpiration = 0;
		myMsg = msg;
		myIsError = isError;
		myDidComplete = false;
		myListener = listener;
		myIsDialog = false;
	}

	FBConnectTask(int listener, String msg, boolean isError, boolean didComplete)
	{
		myType = REQUEST;
		myAccessToken = "";
		myTokenExpiration = 0;
		myMsg = msg;
		myIsError = isError;
		myDidComplete = didComplete;
		myListener = listener;
		myIsDialog = true;
	}

	@Override
	public void executeUsing(CoronaRuntime runtime) {
		switch ( myType ) {
			case SESSION:
				if (myAccessToken != null) {
					(new FBLoginEvent(myAccessToken, myTokenExpiration)).executeUsing(runtime);
				} else {
					(new FBLoginEvent(myPhase)).executeUsing(runtime);
				}
				break;
			case SESSION_ERROR:
				(new FBLoginEvent(FBLoginEvent.Phase.loginFailed, myMsg)).executeUsing(runtime);
		    	break;
			case REQUEST:
				if (myIsDialog) {
					(new FBDialogEvent(myMsg, myIsError, myDidComplete)).executeUsing(runtime);
				} else {
					(new FBRequestEvent(myMsg, myIsError, myDidComplete)).executeUsing(runtime);
				}

				break;
			default:
				break;
		}

		try {
			LuaState L = runtime.getLuaState();
			CoronaLua.dispatchEvent(L, myListener, 0);
		} catch (Exception e) {
			// Log.e("Corona", "FBConnectTask: failed to dispatch event", e);
		}
	}

}
