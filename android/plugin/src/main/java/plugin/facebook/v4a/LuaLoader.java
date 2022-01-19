//
//  LuaLoader.java
//  Facebook-v4a Plugin
//
//  Copyright (c) 2015 Corona Labs Inc. All rights reserved.
//

package plugin.facebook.v4a;

import android.content.ActivityNotFoundException;
import android.util.Log;

import com.ansca.corona.CoronaActivity;
import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeProvider;
import com.ansca.corona.CoronaSystemApiHandler;
import com.facebook.FacebookSdk;
import com.naef.jnlua.JavaFunction;
import com.naef.jnlua.LuaState;
import com.naef.jnlua.LuaType;
import com.naef.jnlua.NamedJavaFunction;

import java.util.ArrayList;
import java.util.Hashtable;

// TODO: Null check Lua states in each namedJavaFunction.
@SuppressWarnings("WeakerAccess")
public class LuaLoader implements JavaFunction {

	// Set to true to compile in debug messages
	private static final boolean Rtt_DEBUG = true; // false;

	@SuppressWarnings("FieldCanBeLocal")
	private CoronaRuntime mRuntime;

	private static final String APP_ID_ERR_MSG = ": appId is no longer a required argument." +
			" This argument will be ignored.";

	/**
	 * Creates a new object for displaying banner ads on the CoronaActivity
	 */
	public LuaLoader() {
		CoronaActivity activity = CoronaEnvironment.getCoronaActivity();

		// Validate.
		if (activity == null) {
			throw new ActivityNotFoundException(
					"ERROR: LuaLoader()" + FacebookController.NO_ACTIVITY_ERR_MSG);
		}
	}

	/**
	 * Warning! This method is not called on the main UI thread.
	 */
	@Override
	public int invoke(LuaState L) {
		mRuntime = CoronaRuntimeProvider.getRuntimeByLuaState(L);

		NamedJavaFunction[] luaFunctions = new NamedJavaFunction[] {
				new DisableLoggingBehaviorsWrapper(),
				new EnableLoggingBehaviorsWrapper(),
				new GetCurrentAccessTokenWrapper(),
				new IsFacebookAppEnabledWrapper(),
				new InitWrapper(),
				new LoginWrapper(),
				new LogoutWrapper(),
//				new NewLikeButtonWrapper(),
				new PublishInstallWrapper(),
				new RequestWrapper(),
				new SetFBConnectListenerWrapper(),
				new ShowDialogWrapper(),
				new GetSDKVersionWrapper(),
		};

		String libName = L.toString( 1 );
		L.register(libName, luaFunctions);

		if (Rtt_DEBUG) Log.i("Corona", "========= Calling FacebookController.facebookInit(): L: " + L + "; mRuntime: " + mRuntime);

		FacebookController.facebookInit(mRuntime);

		return 1;
	}

	private String[] processLoggingBehaviorsFromLua(LuaState L, String methodName) {
		ArrayList<String> loggingBehaviors = new ArrayList<>();

		// Parse args if there are any
		if (L.getTop() != 0) {

			LuaType firstArgType = L.type(1);
			if (firstArgType == LuaType.STRING) {

				// Only passed a single logging behavior, so add it to the list.
				loggingBehaviors.add(L.toString(1));

			} else if (firstArgType == LuaType.TABLE) {

				// Passed in multiple logging behaviors, so grab them all.
				int arrayLength = L.length(1);
				for (int i = 1; i <= arrayLength; i++) {
					L.rawGet(1, i);
					loggingBehaviors.add(L.toString(-1));
					L.pop(1);
				}
			} else {
				Log.i("Corona", "ERROR: " + methodName + ": cannot accept arguments other " +
						"than a String or a Table. Aborting!");
				return null;
			}
		} // If no arguments, then enable all logging behaviors

		//noinspection ToArrayCallWithZeroLengthArrayArgument
		return loggingBehaviors.toArray(new String[0]);
	}

	private class DisableLoggingBehaviorsWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "disableLoggingBehaviors";
		}

		@Override
		public int invoke(LuaState L) {

			String methodName = "facebook." + getName() + "()";
			String[] loggingBehaviorsFromLua = processLoggingBehaviorsFromLua(L, methodName);
			if (loggingBehaviorsFromLua != null) {
				//noinspection ToArrayCallWithZeroLengthArrayArgument
				FacebookController.facebookDisableLoggingBehaviors(loggingBehaviorsFromLua);
			}
			return 0;
		}
	}

	private class EnableLoggingBehaviorsWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "enableLoggingBehaviors";
		}

		@Override
		public int invoke(LuaState L) {

			String methodName = "facebook." + getName() + "()";
			String[] loggingBehaviorsFromLua = processLoggingBehaviorsFromLua(L, methodName);
			if (loggingBehaviorsFromLua != null) {
				//noinspection ToArrayCallWithZeroLengthArrayArgument
				FacebookController.facebookEnableLoggingBehaviors(loggingBehaviorsFromLua);
			}
			return 0;
		}
	}

	private class GetCurrentAccessTokenWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "getCurrentAccessToken";
		}

		@Override
		public int invoke(LuaState L) {

			// Return the Lua table now atop the stack.
			return FacebookController.facebookGetCurrentAccessToken();
		}
	}

	private class IsFacebookAppEnabledWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "isFacebookAppEnabled";
		}

		@Override
		public int invoke(LuaState L) {
			// Grab the method name for error messages:
			String methodName = "facebook." + getName() + "()";

			if (L == null) {
				Log.i("Corona", "ERROR: " + methodName + FacebookController.NO_LUA_STATE_ERR_MSG);
				return 0;
			}

			// Package the result and forward to Lua
			L.pushBoolean(FacebookController.facebookIsFacebookAppEnabled());

			return 1;
		}
	}

	private class InitWrapper implements NamedJavaFunction {

		@Override
		public String getName() {
			return "init";
		}

		@Override
		public int invoke(LuaState L) {

			String methodName = "facebook." + getName() + "()";

			if (CoronaLua.isListener(L, 1, "fbinit")) {
				FacebookController.setFBInitListener(CoronaLua.newRef(L, 1));
			}
			else {
				Log.i("Corona", "ERROR: " + methodName + ": listener is a mandatory parameter");
			}

			return 0;
		}
	}

	private class LoginWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "login";
		}
		
		@Override
		public int invoke(LuaState L) {
			String methodName = "facebook." + getName() + "()";
			ArrayList<String> permissions = new ArrayList<>();
			Boolean limitedLogin = false;
			// Parse args if there are any
			if (L.getTop() != 0) {
				int index = 1;

				LuaType firstArgType = L.type(index);
				if (firstArgType == LuaType.STRING || firstArgType == LuaType.NUMBER) {
					// Warn the user about using deprecated login API
					Log.i("Corona", "WARNING: " + methodName + APP_ID_ERR_MSG);
					// Process the remaining arguments
					index++;
				}

				if (CoronaLua.isListener(L, index, "fbconnect")) {
					FacebookController.setFBConnectListener(CoronaLua.newRef(L, index));
					index++;
				}

				if (L.type(index) == LuaType.TABLE) {
					int arrayLength = L.length(index);
					for (int i = 1; i <= arrayLength; i++) {
						L.rawGet(index, i);
						permissions.add(L.toString(-1));
						L.pop(1);
					}
					index++;
				}
				//Limited Login has not been added to Android(yet?)
				if (L.type(index) == LuaType.BOOLEAN) {
					limitedLogin = L.toBoolean(index);
					System.out.print("Warning: Limited Login is not supported on Android");
				}
			}

			//noinspection ToArrayCallWithZeroLengthArrayArgument
			FacebookController.facebookLogin(permissions.toArray(new String[0]));
			return 0;
		}
	}

	private class LogoutWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "logout";
		}

		@Override
		public int invoke(LuaState L) {
			FacebookController.facebookLogout();
			return 0;
		}
	}

	// TODO: Finish implementing this.
	private class NewLikeButtonWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "newLikeButton";
		}

		@Override
		public int invoke(LuaState L) {
			String methodName = "facebook." + getName() + "()";

			// Parse args if there are any
			//noinspection StatementWithEmptyBody
			if (L.getTop() != 0) {
				// Check for an options table
				//noinspection StatementWithEmptyBody
				if (L.type(1) == LuaType.TABLE) {
					// Grab all the optional arguments from here
				} else {
					// Yell at the user for passing garbage arguments and return.
					Log.i("Corona", "ERROR: " + methodName + ": cannot accept arguments other " +
							"than an options table. Aborting!");
					return 0;
				}
			} else {
				// Insert default arguments to facebookNewLikeButton()
			}

			//FacebookController.facebookNewLikeButton();

			return 0;
		}
	}

	private class PublishInstallWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "publishInstall";
		}

		@Override
		public int invoke(LuaState L) {
			String methodName = "facebook." + getName() + "()";
			if (L.getTop() != 0) {
				// Warn the user about using deprecated login API
				Log.i("Corona", "WARNING: " + methodName + APP_ID_ERR_MSG);
			}
			FacebookController.publishInstall();
			return 0;
		}
	}

	private class RequestWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "request";
		}

		@Override
		public int invoke(LuaState L) {
			int index = 1;

			String path = L.toString(index);
			index++;

			// We default to "GET" if no method is specified.
			// Calling HttpMethod.valueOf(null) has undefined behavior.
			// Doing this prevents that case from occurring within
			// FacebookController.facebookRequest().
			String method = "GET";
			if (L.type(index) == LuaType.STRING) {
				method = L.toString(index);
			}
			index++;

			Hashtable params;
			if (L.type(index) == LuaType.TABLE) {
				params = CoronaLua.toHashtable(L, index);
			} else {
				params = new Hashtable();
			}

			FacebookController.facebookRequest(path, method, params);

			return 0;
		}
	}

	private class SetFBConnectListenerWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "setFBConnectListener";
		}

		@Override
		public int invoke(LuaState L) {
			String methodName = "facebook." + getName() + "()";
			if (CoronaLua.isListener(L, 1, "fbconnect")) {
				FacebookController.setFBConnectListener(CoronaLua.newRef(L, 1));
			} else {
				Log.i("Corona", "ERROR: " + methodName + ": Please provide a listener.");
			}
			return 0;
		}
	}

	private class ShowDialogWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "showDialog";
		}

		@Override
		public int invoke(LuaState L) {
			String methodName = "facebook." + getName() + "()";
			String action;
			Hashtable params = null;

			if (L.isString(1)) {

				action = L.toString(1);

				if (L.type(2) == LuaType.TABLE) {
					params = CoronaLua.toHashtable(L, 2);
				}

				FacebookController.facebookDialog(action, params);

			} else {
				Log.i("Corona", "ERROR: " + methodName +
						FacebookController.INVALID_PARAMS_SHOW_DIALOG_ERR_MSG);
			}

			return 0;
		}
	}

	private class GetSDKVersionWrapper implements NamedJavaFunction
	{
		@Override
		public String getName() {
			return "getSDKVersion";
		}

		@Override
		public int invoke(LuaState L) {
			//String methodName = "facebook."+getName()+"()" ;
			//Log.i("Corona", "============= Current SDK version is "+ FacebookSdk.getSdkVersion()+ " ============== ");
			L.pushString(FacebookSdk.getSdkVersion());
			return 1;
		}
	}
}
