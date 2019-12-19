//
//  FacebookController.java
//  Facebook-v4a Plugin
//  Edited by Kirill
//  Copyright (c) 2018 Corona Labs Inc. All rights reserved.
//

package plugin.facebook.v4a;

/*
 * Android classes
 */
import android.Manifest.permission;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Process;
import android.util.Log;

import com.ansca.corona.CoronaActivity;
import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeTask;
import com.ansca.corona.permissions.PermissionsServices;
import com.ansca.corona.permissions.PermissionsSettings;
import com.ansca.corona.storage.FileServices;
import com.ansca.corona.storage.PackageServices;
import com.ansca.corona.storage.PackageState;
import com.facebook.AccessToken;
import com.facebook.AccessTokenTracker;
import com.facebook.CallbackManager;
import com.facebook.FacebookCallback;
import com.facebook.FacebookException;
import com.facebook.FacebookSdk;
import com.facebook.GraphRequest;
import com.facebook.GraphResponse;
import com.facebook.HttpMethod;
import com.facebook.LoggingBehavior;
import com.facebook.appevents.AppEventsLogger;
import com.facebook.login.LoginManager;
import com.facebook.login.LoginResult;
import com.facebook.share.Sharer;
import com.facebook.share.internal.ShareFeedContent;
import com.facebook.share.model.GameRequestContent;
import com.facebook.share.model.GameRequestContent.ActionType;
import com.facebook.share.model.GameRequestContent.Filters;
import com.facebook.share.model.ShareLinkContent;
import com.facebook.share.model.SharePhoto;
import com.facebook.share.model.SharePhotoContent;
import com.facebook.share.widget.GameRequestDialog;
import com.facebook.share.widget.ShareDialog;
import com.naef.jnlua.LuaState;
import com.naef.jnlua.LuaType;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.Hashtable;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;

/*
 * Corona classes
 */
/*
 * Facebook classes
 */
//import com.facebook.share.model.ShareOpenGraphAction;
//import com.facebook.share.model.ShareOpenGraphContent;
//import com.facebook.share.model.ShareOpenGraphObject;
/*
 * Java classes
 */
/*
 * JNLua classes
 */

class FacebookController {

	// Set to true to compile in debug messages
	private static final boolean Rtt_DEBUG = true; // false;
    private static final String PUBLISH_PERMISSION_PREFIX = "publish";
    private static final String MANAGE_PERMISSION_PREFIX = "manage";
    private static final Set<String> OTHER_PUBLISH_PERMISSIONS = getOtherPublishPermissions();
    /************************************** Member Variables **************************************/
    private static int sListener;
    private static int sInitListener;
	private static int sLibRef;
    private static CallbackManager sCallbackManager;
    private static AccessTokenTracker sAccessTokenTracker;
    private static CoronaRuntime sCoronaRuntime;
    private static PermissionsServices sPermissionsServices;
    private static Intent sPlacesOrFriendsIntent;
    private static final FacebookActivityResultHandler fbActivityResultHandler = new FacebookActivityResultHandler();
    // TODO: Add this back in for automatic token refresh.
    //private static final AtomicBoolean accessTokenRefreshInProgress = new AtomicBoolean(false);

	private static final AtomicBoolean finishedFBSDKInit = new AtomicBoolean(false);
	private static boolean initAlreadyDispatched = false;

    // Dialogs
    private static ShareDialog sShareDialog;
    private static GameRequestDialog sRequestDialog;

    // Error messages
    public static final String NO_ACTIVITY_ERR_MSG = ": cannot continue without a CoronaActivity." +
            " User action (hitting the back button) or another thread may have destroyed it.";
    @SuppressWarnings("WeakerAccess")
    public static final String NO_RUNTIME_ERR_MSG = ": cannot continue without a CoronaRuntime. " +
            "User action or another thread may have destroyed it.";
    @SuppressWarnings("WeakerAccess")
    public static final String NO_LUA_STATE_ERR_MSG = ": the Lua state has died! Abort";
    @SuppressWarnings("WeakerAccess")
    public static final String DIALOG_CANCELLED_MSG = "Dialog was cancelled by user.";
    public static final String INVALID_PARAMS_SHOW_DIALOG_ERR_MSG = ": Invalid parameters passed " +
            "to facebook.showDialog( action [, params] ).";
    /**
     * Login callback
     */
    private static final FacebookCallback<LoginResult> loginCallback =
            new FacebookCallback<LoginResult>() {
                @Override
                public void onSuccess(LoginResult loginResults) {

                    // Grab the method name for error messages:
                    String methodName = "FacebookController.loginCallback.onSuccess()";
					if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

                    AccessToken currentAccessToken = AccessToken.getCurrentAccessToken();
                    if (currentAccessToken == null || // Should never happen if login was successful
                            !loginResults.getAccessToken().equals(currentAccessToken)) {
                        Log.i("Corona", "ERROR: " + methodName + ": lost the access token. This " +
                                "could be the result of another thread completing " +
                                "facebook.logout() before this callback was invoked.");
                    } else {
                        dispatchLoginFBConnectTask(methodName, FBLoginEvent.Phase.login,
                                currentAccessToken.getToken(), currentAccessToken.getExpires().getTime());
                    }
                }

                @Override
                public void onCancel() {
                    // Grab the method name for error messages:
                    String methodName = "FacebookController.loginCallback.onCancel()";
					if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

                    dispatchLoginFBConnectTask(methodName,
                            FBLoginEvent.Phase.loginCancelled, null, 0);
                }

                @Override
                public void onError(FacebookException exception) {
                    // Grab the method name for error messages:
                    String methodName = "FacebookController.loginCallback.onError()";
					if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

                    dispatchLoginErrorFBConnectTask(methodName, exception.getLocalizedMessage());
                }
            };

    /**
     * Share dialog callback
     */
    private static final FacebookCallback<Sharer.Result> shareCallback =
            new FacebookCallback<Sharer.Result>() {
                @Override
                public void onSuccess(Sharer.Result result) {
                    // Grab the method name for error messages:
                    String methodName = "FacebookController.shareCallback.onSuccess()";
					if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

                    // Compose response with info about what happened
                    Uri.Builder builder = new Uri.Builder();
                    builder.authority("success");
                    builder.scheme("fbconnect");
                    String postId = result.getPostId();
                    postId = postId == null ? "" : postId;
                    builder.appendQueryParameter("PostID", postId);

                    dispatchDialogFBConnectTask(methodName,
                            builder.build().toString(), false, true);
                }

                @Override
                public void onCancel() {
                    // Grab the method name for error messages:
                    String methodName = "FacebookController.shareCallback.onCancel()";
					if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

                    dispatchDialogFBConnectTask(methodName, DIALOG_CANCELLED_MSG, false, true);
                }

                @Override
                public void onError(FacebookException error) {
                    // Grab the method name for error messages:
                    String methodName = "FacebookController.shareCallback.onError()";
					if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

                    dispatchDialogFBConnectTask(methodName,
                            error.getLocalizedMessage(), true, false);
                }
            };

    /**
     * Game Request Dialog callback
     */
    private static final FacebookCallback<GameRequestDialog.Result> requestCallback =
            new FacebookCallback<GameRequestDialog.Result>() {
                @Override
                public void onSuccess(GameRequestDialog.Result result) {
                    // Grab the method name for error messages:
                    String methodName = "FacebookController.requestCallback.onSuccess()";
					if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

                    // Compose response with info about what happened
                    Uri.Builder builder = new Uri.Builder();
                    builder.authority("success");
                    builder.scheme("fbconnect");

                    // Request ID
                    String requestId = result.getRequestId();
                    requestId = requestId == null ? "" : requestId;
                    builder.appendQueryParameter("RequestID", requestId);

                    // Request Recipients
                    List<String> requestRecipients = result.getRequestRecipients();
                    for(String recipient : requestRecipients) {
                        recipient = recipient == null ? "" : recipient;
                        builder.appendQueryParameter("Recipient", recipient);
                    }

                    dispatchDialogFBConnectTask(methodName,
                            builder.build().toString(), false, true);
                }

                @Override
                public void onCancel() {
                    // Grab the method name for error messages:
                    String methodName = "FacebookController.requestCallback.onCancel()";
					if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

                    dispatchDialogFBConnectTask(methodName, DIALOG_CANCELLED_MSG, false, true);
                }

                @Override
                public void onError(FacebookException error) {
                    // Grab the method name for error messages:
                    String methodName = "FacebookController.requestCallback.onError()";
					if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

                    dispatchDialogFBConnectTask(methodName,
                            error.getLocalizedMessage(), true, false);
                }
            };

    /**
     * FBConnectTask Wrappers
     */
    private static void dispatchFBInitEvent(String fromMethod) {

		final String methodName = "FacebookController.dispatchFBInitEvent()";

		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName + "; from: " + fromMethod + "; sCoronaRuntime: " + sCoronaRuntime + "; sInitListener: " + sInitListener + "; initAlreadyDispatched: " + initAlreadyDispatched);

		if (! initAlreadyDispatched) {

			if (sCoronaRuntime != null && sInitListener != 0) {
				sCoronaRuntime.getTaskDispatcher().send( new CoronaRuntimeTask() {
					@Override
					public void executeUsing(CoronaRuntime runtime) {
						LuaState L = runtime.getLuaState();

						CoronaLua.newEvent( L, "fbinit" );

						L.pushString("initialized");
						L.setField(-2, "phase");

						// TODO: maybe include the current access token but it seems to be null here

						try {
							if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName + ": dispatching fbinit event" );
							CoronaLua.dispatchEvent( L, sInitListener, 0 );
						}
						catch (Exception ignored) {
						}
					}
				} );

				initAlreadyDispatched = true;
			}
		}
    }

    private static void dispatchLoginFBConnectTask(String fromMethod, FBLoginEvent.Phase phase,
                                                   String accessToken, long tokenExpiration) {
        // Create local reference to sCoronaRuntime and null check it to guard against
        // the possibility of a separate thread nulling out sCoronaRuntime, say if the
        // Activity got destroyed.
        CoronaRuntime runtime = sCoronaRuntime;
        if (runtime != null) {
            // When we reach here, we're done with requesting permissions,
            // so we can go back to the lua side
            runtime.getTaskDispatcher().send(new FBConnectTask(
                    sListener, phase, accessToken, tokenExpiration));
        } else {
            Log.i("Corona", "ERROR: " + fromMethod + NO_RUNTIME_ERR_MSG);
        }
    }

    private static void dispatchLoginErrorFBConnectTask(String fromMethod, String msg) {
        // Create local reference to sCoronaRuntime and null check it to guard against
        // the possibility of a separate thread nulling out sCoronaRuntime, say if the
        // Activity got destroyed.
        CoronaRuntime runtime = sCoronaRuntime;
        if (runtime != null) {
            runtime.getTaskDispatcher().send(
                    new FBConnectTask(sListener, msg));
        } else {
            Log.i("Corona", "ERROR: " + fromMethod + NO_RUNTIME_ERR_MSG);
        }
    }

    private static void dispatchDialogFBConnectTask(String fromMethod, String msg,
                                                    boolean isError, boolean didComplete) {
        // Create local reference to sCoronaRuntime and null check it to guard against
        // the possibility of a separate thread nulling out sCoronaRuntime, say if the
        // Activity got destroyed.
        CoronaRuntime runtime = sCoronaRuntime;
        if (runtime != null) {
            // Send response back to lua
            runtime.getTaskDispatcher().send(new FBConnectTask(
                    sListener, msg, isError, didComplete));
        } else {
            Log.i("Corona", "ERROR: " + fromMethod + NO_RUNTIME_ERR_MSG);
        }
    }

    /**
     * Other utilities
     */
    // For inner classes, we grab a new reference to the Lua state here as opposed to declaring
    // a final variable containing the Lua State to cover the case of the initial LuaState being
    // closed by something out of our control, like the user destroying the
    // CoronaActivity and then recreating it.
    private static LuaState fetchLuaState() {
        // Grab the method name for error messages:
        String methodName = "FacebookController.fetchLuaState()";

        // Create local reference to sCoronaRuntime and null check it to guard against
        // the possibility of a separate thread nulling out sCoronaRuntime, say if the
        // Activity got destroyed.
        CoronaRuntime runtime = sCoronaRuntime;
        if (runtime != null) {
			if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName + ": " + runtime.getLuaState() );
            return runtime.getLuaState();
        } else {
            Log.i("Corona", "ERROR: " + methodName + NO_RUNTIME_ERR_MSG);
            return null;
        }
    }

    // Converts a long in milliseconds to seconds
    private static long toSecondsFromMilliseconds(long timeInMilliseconds) {
        return timeInMilliseconds/1000;
    }

    // Compares strings to enum names ignoring case.
    // Based on: http://stackoverflow.com/questions/28332924/
    // case-insensitive-matching-of-a-string-to-a-java-enum
    @SuppressWarnings("WeakerAccess")
    public static <T extends Enum<T>> T enumValueOfIgnoreCase(Class<T> enumType, String name) {
        for (T enumToCheck : enumType.getEnumConstants()) {
            if (enumToCheck.name().equalsIgnoreCase(name)) {
                return enumToCheck;
            }
        }
        return null;
    }

    // Creates a Lua table out of an array of strings.
    // Leaves the Lua table on top of the stack.
    private static int createLuaTableFromStringArray(String[] array) {
        // Grab the method name for error messages:
        String methodName = "FacebookController.createLuaTableFromStringArray()";
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

        if (array == null) {
            Log.i("Corona", "ERROR: " + methodName + ": cannot create a lua table from a null " +
                    "array! Please pass in a non-null string array.");
            return 0;
        }

		LuaState L = fetchLuaState();
		if (L == null) {
			Log.i("Corona", "ERROR: " + methodName + NO_LUA_STATE_ERR_MSG);
			return 0;
		}

		L.newTable(array.length, 0);
		for (int i = 0; i < array.length; i++) {
			// Push this string to the top of the stack
			L.pushString(array[i]);

			// Assign this string to the table 2nd from the top of the stack.
			// Lua arrays are 1-based so add 1 to index correctly.
			L.rawSet(-2, i + 1);
		}

        // Result is on top of the lua stack.
        return 1;
    }

    private static Bundle createFacebookBundle(Hashtable map) {
        Bundle result = new Bundle();

        if ( null != map ) {
            Hashtable< String, Object > m = (Hashtable< String, Object >)map;
            Set< Map.Entry< String, Object > > s = m.entrySet();
            Context context = CoronaEnvironment.getApplicationContext();
            FileServices fileServices;
            fileServices = new FileServices(context);
            for (Map.Entry<String, Object> entry : s) {
                String key = entry.getKey();
                Object value = entry.getValue();

                if (value instanceof File) {
                    byte[] bytes = fileServices.getBytesFromFile(((File) value).getPath());
                    if (bytes != null) {
                        result.putByteArray(key, bytes);
                    }
                } else if (value instanceof byte[]) {
                    result.putByteArray(key, (byte[]) value);
                } else if (value instanceof String[]) {
                    result.putStringArray(key, (String[]) value);
                } else if (value != null) {
                    boolean done = false;
                    File f = new File(value.toString());
                    if (f.exists()) {
                        byte[] bytes = fileServices.getBytesFromFile(f);
                        if (bytes != null) {
                            result.putByteArray(key, bytes);
                            done = true;
                        }
                    }

                    if (!done) {
                        result.putString(key, value.toString());
                    }
                }
            }
        }
        return result;
    }

    // Enforce proper setup of the project, throwing exceptions if setup is incorrect.
    private static void verifySetup(final CoronaActivity activity) {
        // Grab the method name for error messages:
        String methodName = "FacebookController.verifySetup()";
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

        // Throw an exception if this application does not have the internet permission.
        // Without it the web dialogs won't show.
        if (activity != null) {
            // TODO: USE PERMISSIONS FRAMEWORK TO ENFORCE INTERNET PERMISSION HERE!
            activity.enforceCallingOrSelfPermission(permission.INTERNET, null);
        } else {
            Log.i("Corona", "ERROR: " + methodName + NO_ACTIVITY_ERR_MSG);
            return;
        }

        final String noFacebookAppIdMessage = "To develop for Facebook Connect, you need to get " +
                "a Facebook App ID and integrate it into your Corona project.";
        // Ensure the user provided a Facebook App ID.
        // Based on: http://www.coderzheaven.com/2013/10/03/meta-data-android-manifest-accessing-it/
        try {
            ApplicationInfo ai = activity.getPackageManager().getApplicationInfo(
                    activity.getPackageName(), PackageManager.GET_META_DATA);
            Bundle bundle = ai.metaData;
            final String facebookAppId = bundle.getString("com.facebook.sdk.ApplicationId");
			if (Rtt_DEBUG) Log.i("Corona", "++++++++++: facebookAppId: " + facebookAppId );
            if (facebookAppId == null || ! android.text.TextUtils.isDigitsOnly(facebookAppId)) {
                activity.getHandler().post( new Runnable() {
                    @Override
                    public void run() {
                        AlertDialog alertDialog = activity.createAlertDialogBuilder(activity)
                                .setTitle("ERROR: Invalid Facebook App ID")
                                .setMessage(noFacebookAppIdMessage + "\n\n" + (facebookAppId == null ? "missing" : facebookAppId))
                                .setPositiveButton("Get App ID",
                                        new DialogInterface.OnClickListener() {
                                            public void onClick(DialogInterface dialog, int id) {
                                                // Open Facebook dev portal:
                                                Uri uri = Uri.parse(
                                                        "https://developers.facebook.com/");
                                                Intent intent = new Intent(Intent.ACTION_VIEW, uri);
                                                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                                activity.startActivity(intent);

                                                // Close this app
                                                Process.killProcess(Process.myPid());
                                            }
                                        })
                                .setNeutralButton("Integrate in Corona",
                                        new DialogInterface.OnClickListener() {
                                            public void onClick(DialogInterface dialog, int id) {
                                                // Open Corona's Integrating Facebook guide:
                                                Uri uri = Uri.parse(
														"https://docs.coronalabs.com/guide/social/usingFacebook/index.html");
                                                Intent intent = new Intent(Intent.ACTION_VIEW, uri);
                                                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                                activity.startActivity(intent);

                                                // Close the application
                                                Process.killProcess(Process.myPid());
                                            }
                                        })
                                        // Handle the user cancelling the dialog,
                                        // with the back button in particular.
                                .setOnCancelListener(new DialogInterface.OnCancelListener() {
                                    public void onCancel(DialogInterface dialog) {
                                        // Close the application
                                        Process.killProcess(Process.myPid());
                                    }
                                })
                                .create();
                        alertDialog.setCanceledOnTouchOutside(false);
                        alertDialog.show();
                    }
                });
                // Block this thread since the app shouldn't continue with no Facebook App ID
				try {
					// Pump message loop
					android.os.Looper.loop();
				}
				catch(RuntimeException ignored) {}
            }
        } catch (Exception e) {
			Log.e("Corona", methodName + ": error looking for Facebook App ID", e);
        }
    }

    private static void loginWithOnlyRequiredPermissions() {
        // Grab the method name for error messages:
        String methodName = "FacebookController.loginWithOnlyRequiredPermissions()";

        CoronaActivity activity = CoronaEnvironment.getCoronaActivity();
        if (activity == null) {
            Log.i("Corona", "ERROR: " + methodName + NO_ACTIVITY_ERR_MSG);
            return;
        }
        // The "public_profile" permission as this is expected of facebook.
        // We include the "user_friends" permission by default for legacy reasons.
        LoginManager.getInstance().logInWithReadPermissions(activity,
                Arrays.asList("public_profile"));//, "user_friends"));
    }

    private static boolean isPublishPermission(String permission) {
        return permission != null &&
                (permission.startsWith(PUBLISH_PERMISSION_PREFIX) ||
                        permission.startsWith(MANAGE_PERMISSION_PREFIX) ||
                        OTHER_PUBLISH_PERMISSIONS.contains(permission));
    }

    private static Set<String> getOtherPublishPermissions() {
        HashSet<String> set = new HashSet<String>() {{
            add("ads_management");
            add("create_event");
            add("rsvp_event");
        }};
        return Collections.unmodifiableSet(set);
    }

    private static void requestPermissions(String permissions[]) {
        // Grab the method name for error messages:
        String methodName = "FacebookController.requestPermissions()";
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

        if (permissions == null) {
            Log.i("Corona", "ERROR: " + methodName + ": Permissions held by this app" +
                    " are null. Be sure to provide at least an empty permission list" +
                    " to facebook.login() before requesting permissions.");
            return;
        }

        // Remove the permissions we already have access to
        // so that we don't try to get access to them again
        // causing constant flashes on the screen
        AccessToken currentAccessToken = AccessToken.getCurrentAccessToken();
        if (currentAccessToken != null) {
            Set grantedPermissions = currentAccessToken.getPermissions();
            for (int i = 0; i < permissions.length; i++) {
                if (grantedPermissions.contains(permissions[i])) {
                    permissions[i] = null;
                }
            }
        } else if (permissions.length == 0) {
            // They still need to login, but aren't requesting any permissions.
            loginWithOnlyRequiredPermissions();
        } // else { // Need to request all the desired permissions again }

        // Look for permissions to be requested
        List<String> readPermissions = new LinkedList<>();
        List<String> publishPermissions = new LinkedList<>();

        for (int i = 0; i < permissions.length; i++) {
            if (permissions[i] != null) {
                if (isPublishPermission(permissions[i])) {
                    publishPermissions.add(permissions[i]);
                } else {
                    readPermissions.add(permissions[i]);
                }
                permissions[i] = null;
            }
        }

        // If someone is trying to request additional permissions before
        // doing an initial login, tack on the required read permissions.
        String[] requiredPermissions = { "public_profile" };//, "user_friends"};
        for (String requiredPermission : requiredPermissions) {

            // If they haven't requested one of the required permissions and
            // they either aren't logged in, or don't already have this required permission.
            if (!readPermissions.contains(requiredPermission) &&
                    (currentAccessToken == null ||
                            !currentAccessToken.getPermissions().contains(requiredPermission))) {
                readPermissions.add(requiredPermission);
            }
        }

        CoronaActivity activity = CoronaEnvironment.getCoronaActivity();
        if (activity == null) {
            Log.i("Corona", "ERROR: " + methodName + NO_ACTIVITY_ERR_MSG);
            return;
        }

        // If there are some permissions we haven't requested yet then we request them.
        if (!readPermissions.isEmpty()) {
            // Throw a warning if the user is trying to request
            // read and publish permissions at the same time.
            if (!publishPermissions.isEmpty()) {
                Log.i("Corona", "WARNING: " + methodName + ": cannot process read and publish " +
                        "permissions at the same time. Only the read permissions will be " +
                        "requested.");
            }
            LoginManager.getInstance().logInWithReadPermissions(activity, readPermissions);
        } else if (!publishPermissions.isEmpty()) {
            LoginManager.getInstance().logInWithPublishPermissions(activity, publishPermissions);
        } else if (currentAccessToken == null) {
            // They still need to login, but were a jerk and passed in a permissions array
            // containing only nulls. So login with only required permissions.
            loginWithOnlyRequiredPermissions();
        } else {
            // We've already been granted all these permissions.
            // Return successful login phase so Lua can move on.
            dispatchLoginFBConnectTask(methodName, FBLoginEvent.Phase.login,
                    currentAccessToken.getToken(), currentAccessToken.getExpires().getTime());
        }
    }

    /**
     * Verifies that this String corresponds to a Share action.
     * @param action The String to verify
     * @return Returns true if this String corresponds to a Share action.
     */
    private static boolean isShareAction(String action) {
        return  action.equals("feed") ||
                action.equals("link") ||
                action.equals("photo") ||
                action.equals("video") ||
                action.equals("openGraph");
    }

    /**
     * Brings up a dialog, asking the user for permission to access the location hardware.
     */
    private static void requestLocationPermission() {

        if (sPermissionsServices == null) {
            sPermissionsServices = new PermissionsServices(
                    CoronaEnvironment.getApplicationContext());
        }
        // Create our Permissions Settings to compare against in the handler.
        String[] permissionsToRequest = sPermissionsServices.
                findAllPermissionsInManifestForGroup(PermissionsServices.PermissionGroup.LOCATION);

        // Request Location permission.
        sPermissionsServices.requestPermissions(new PermissionsSettings(permissionsToRequest),
                new LocationRequestPermissionsResultHandler());
    }

    /**
     * Verifies that this String corresponds to a Logging Behavior.
     * @param behavior The String to verify
     * @return Returns true if this String corresponds to a Logging Behavior.
     */
    private static boolean isLoggingBehavior(String behavior) {
        return LuaFBLoggingBehavior.contains(behavior);
    }

    private static String[] loggingBehaviorFilter(String[] loggingBehaviors,
                                                  String callingMethodName) {

        ArrayList<String> filteredLoggingBehaviors = new ArrayList<>();

        // Only run the filter if there's something to run it on.
        if (loggingBehaviors != null && loggingBehaviors.length != 0) {
            for (String loggingBehavior : loggingBehaviors) {
                if (isLoggingBehavior(loggingBehavior)) {
                    filteredLoggingBehaviors.add(loggingBehavior);
                } else {
                    Log.i("Corona", "WARNING: " + callingMethodName + ": detected an invalid " +
                            "logging behavior " + loggingBehavior + ". This " +
                            "behavior will be filtered out.");
                }
            }
        }

        //noinspection ToArrayCallWithZeroLengthArrayArgument
        return filteredLoggingBehaviors.toArray(new String[0]);
    }

	// Set the 'isActive' and 'currentAccessToken' members of the facebook table
	public static void setPluginsLuaVariables(AccessToken accessToken) {

		final String methodName = "FacebookController.setPluginsLuaVariables()";

		LuaState L = fetchLuaState(); // runtime.getLuaState();

		if (L != null)
		{
            int top = L.getTop();
			L.rawGet(LuaState.REGISTRYINDEX, sLibRef);

			if (L.type(-1) == LuaType.TABLE)
			{
				// Let lua know that facebook has been initialized and give the currentAccessToken.

				String accessTokenString = "";

				// If we weren't given an access token, see if there's one available
				if (accessToken == null && finishedFBSDKInit.get()) {
					accessToken = AccessToken.getCurrentAccessToken();
				}

				if (accessToken != null) {
					accessTokenString = accessToken.getToken();
				}

				if (Rtt_DEBUG) Log.i("Corona", "++++++++++: setPluginsLuaVariables setting currentAccessToken = \"" + accessTokenString + "\"" );

				L.pushString(accessTokenString);
				L.setField(-2, "currentAccessToken");

				if (Rtt_DEBUG) Log.i("Corona", "++++++++++: setPluginsLuaVariables setting isActive = " + finishedFBSDKInit.get() );
				L.pushBoolean(finishedFBSDKInit.get());
				L.setField(-2, "isActive");
			}
			else
			{
				// Sometimes we don't find the right thing on the Lua stack
				// (this was most likely resolved by synchronizing the access through the GLThread)
				if (Rtt_DEBUG) {
					Log.e("Corona", methodName + ": expected TABLE but found " + L.typeName(-1));
					if (L.type(-1) == LuaType.STRING || L.type(-1) == LuaType.NUMBER) {
						Log.e("Corona", methodName + ": with value \"" + L.toString(-1) + "\"");
					}
				}
			}
            L.setTop(top);
		}
	}

	// This sets the plugin's Lua state variables on the Lua thread so the LuaState doesn't get corrupted
	// (note that it might be a while before it's scheduled by the Lua thread, e.g. at the end of main.lua)
	private static void setPluginsLuaVariablesAsync(final AccessToken accessToken)
	{
        CoronaActivity activity = CoronaEnvironment.getCoronaActivity();

		if (activity != null)
		{
			com.ansca.corona.CoronaRuntimeTaskDispatcher dispatcher = activity.getRuntimeTaskDispatcher();

			if (dispatcher != null)
			{
				dispatcher.send( new CoronaRuntimeTask() {
					@Override
					public void executeUsing(CoronaRuntime runtime)
					{
						setPluginsLuaVariables(accessToken);
					}
				} );
			}
		}
	}

    /**********************************************************************************************/
    /********************************** API Implementations ***************************************/
    /**
     * require("plugin.facebook.v4a") entry point
     *
     * This will verifySetup and Facebook initialization as well as setup callbacks for everything.
     *
     * @param runtime: The Corona runtime that facebook should interact with.
     *
     * TODO: refreshing accessTokens if needed
     */
	public static void facebookInit(CoronaRuntime runtime) {
		// Grab the method name for error messages:
		final String methodName = "FacebookController.facebookInit()";
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

		// Certain app lifecycles (certainly while debugging) seem to leave this set to true
		// after an initial run so we reset it explicitly here
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: setting finishedFBSDKInit = false" );
		finishedFBSDKInit.set(false);
		initAlreadyDispatched = false;

		final CoronaActivity activity = CoronaEnvironment.getCoronaActivity();
		if (activity == null) {
			Log.i("Corona", "ERROR: " + methodName + NO_ACTIVITY_ERR_MSG);
			return;
		} else {
			sPermissionsServices = new PermissionsServices(
					CoronaEnvironment.getApplicationContext());
			verifySetup(activity);
		}

		if (runtime == null) {
			Log.i("Corona", "ERROR: " + methodName + NO_RUNTIME_ERR_MSG);
			return;
		} else {
			sCoronaRuntime = runtime;
		}

		// Make sure only one thread accesses the LuaState at a time
		LuaState L = fetchLuaState();
		if (L == null) {
			Log.i("Corona", "ERROR: " + methodName + NO_LUA_STATE_ERR_MSG);
			return;
		} else {
			// Initialize currentAccessToken field and isActive fields
			sLibRef = CoronaLua.newRef(L, -1);
			L.pushString("");
			L.setField(-2, "currentAccessToken");

			L.pushBoolean(false);
			L.setField(-2, "isActive");
		}
		// Initialize Facebook, create dialogs, and register callbacks on UI thread.
		activity.runOnUiThread(new Runnable() {
			@Override
			public void run() {

				if (Rtt_DEBUG)
				{
					Log.i("Corona", "++++++++++: " + "Initialize Facebook on UI thread" );
					logThreadSignature("Initialize Facebook");
				}

				//activity.registerActivityResultHandler(fbActivityResultHandler, 0xface);
                activity.unregisterActivityResultHandler(fbActivityResultHandler);

                int requestCodeOffset = activity.registerActivityResultHandler(
                        fbActivityResultHandler, 0xface); //100
                if (!FacebookSdk.isInitialized()) {
                    // Initialize the Facebook SDK
                    FacebookSdk.sdkInitialize(activity.getApplicationContext(), requestCodeOffset);
                }

				// Create our callback manager and set up forwarding of login results
                sCallbackManager = CallbackManager.Factory.create();

                // Callback registration
                LoginManager.getInstance().registerCallback(sCallbackManager, loginCallback);

                sShareDialog = new ShareDialog(activity);
                sShareDialog.registerCallback(
                        sCallbackManager,
                        shareCallback);

                sRequestDialog = new GameRequestDialog(activity);
                sRequestDialog.registerCallback(
                        sCallbackManager,
                        requestCallback);

				// Set up access token tracker to handle login events
				sAccessTokenTracker = new AccessTokenTracker() {

					@Override
					protected void onCurrentAccessTokenChanged(
							AccessToken oldAccessToken,
							AccessToken currentAccessToken) {

								String methodName = "FacebookController.sAccessTokenTracker." +
									"onCurrentAccessTokenChanged.accessTokenToLuaTask." +
									"executeUsing()";

								if (Rtt_DEBUG)
								{
									Log.i("Corona", "++++++++++: " + methodName );
									logThreadSignature(methodName);
								}

								// We grab a new reference to the Lua state here as opposed to
								// declaring a final variable containing the Lua State to cover the
								// case of the initial LuaState being closed by something out of our
								// control, like the user destroying the CoronaActivity and then
								// recreating it.
								// Make sure only one thread accesses the LuaState at a time

								setPluginsLuaVariablesAsync(currentAccessToken);
							}
				};

				synchronized(this) {
					AccessToken currentAccessToken = AccessToken.getCurrentAccessToken();

					setPluginsLuaVariablesAsync(currentAccessToken);

					dispatchFBInitEvent(methodName);
				}

				if (Rtt_DEBUG) Log.i("Corona", "++++++++++: setting finishedFBSDKInit = true" );

				finishedFBSDKInit.set(true);
			}
		});

	}

    /**
     * facebook.disableLoggingBehaviors entry point
     */
    public static void facebookDisableLoggingBehaviors(String loggingBehaviors[]) {
        // Grab the method name for error messages:
        String methodName = "FacebookController.facebookDisableLoggingBehaviors()";
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

        if (loggingBehaviors == null) {
            Log.i("Corona", "ERROR: " + methodName + ": Can't set logging behaviors to null! " +
                    "Be sure to pass in an initialized array of logging behaviors.");
        } else if (loggingBehaviors.length == 0) {
            // Disable all logging behaviors available to Corona users.
            FacebookSdk.clearLoggingBehaviors();
            FacebookSdk.setIsDebugEnabled(false);
            // TODO: Special PluginAndFacebookSDKCommunicationOption
        } else {
            // Disable only the specified logging behaviors.

            // Filter out invalid arguments.
            String[] filteredLoggingBehaviors = loggingBehaviorFilter(loggingBehaviors, methodName);

            // Disable valid arguments.
            for (String filteredLoggingBehavior : filteredLoggingBehaviors) {

                // TODO: TEST THIS!
                switch (LuaFBLoggingBehavior.valueOf(filteredLoggingBehavior)) {
                    case ACCESS_TOKENS:
                        FacebookSdk.removeLoggingBehavior(LoggingBehavior.INCLUDE_ACCESS_TOKENS);
                        break;
                    case APP_EVENTS:
                        FacebookSdk.removeLoggingBehavior(LoggingBehavior.APP_EVENTS);
                        break;
                    case CACHE:
                        FacebookSdk.removeLoggingBehavior(LoggingBehavior.CACHE);
                        break;
                    case GRAPH_API_DEBUG_WARNING:
                        FacebookSdk.removeLoggingBehavior(LoggingBehavior.GRAPH_API_DEBUG_WARNING);
                        break;
                    case GRAPH_API_DEBUG_INFO:
                        FacebookSdk.removeLoggingBehavior(LoggingBehavior.GRAPH_API_DEBUG_INFO);
                        break;
                    case NETWORK_REQUESTS:
                        FacebookSdk.removeLoggingBehavior(LoggingBehavior.INCLUDE_RAW_RESPONSES);
                        FacebookSdk.removeLoggingBehavior(LoggingBehavior.REQUESTS);
                        break;
                    case PLUGIN_AND_FACEBOOK_SDK_COMMUNICATION:
                        // TODO
                        break;
                    default:
                        break;
                }
            }
        }
    }

    /**
     * facebook.enableLoggingBehaviors entry point
     */
    public static void facebookEnableLoggingBehaviors(String loggingBehaviors[]) {
        // Grab the method name for error messages:
        String methodName = "FacebookController.facebookEnableLoggingBehaviors()";
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

        if (loggingBehaviors == null) {
            Log.i("Corona", "ERROR: " + methodName + ": Can't set logging behaviors to null! " +
                    "Be sure to pass in an initialized array of logging behaviors.");
        } else if (loggingBehaviors.length == 0) {
            // Enable all logging behaviors available to Corona users.
            FacebookSdk.setIsDebugEnabled(true);
            // We don't need to check for duplicates since Facebook's logging behaviors are stored
            // as a HashSet, which automatically handles duplicates.
            FacebookSdk.addLoggingBehavior(LoggingBehavior.INCLUDE_ACCESS_TOKENS);
            FacebookSdk.addLoggingBehavior(LoggingBehavior.APP_EVENTS);
            FacebookSdk.addLoggingBehavior(LoggingBehavior.CACHE);
            FacebookSdk.addLoggingBehavior(LoggingBehavior.GRAPH_API_DEBUG_WARNING);
            FacebookSdk.addLoggingBehavior(LoggingBehavior.GRAPH_API_DEBUG_INFO);
            FacebookSdk.addLoggingBehavior(LoggingBehavior.REQUESTS);
            FacebookSdk.addLoggingBehavior(LoggingBehavior.INCLUDE_RAW_RESPONSES);
            // TODO: Special PluginAndFacebookSDKCommunicationOption
        } else {
            // Enable only the specified logging behaviors.

            // Filter out invalid arguments.
            String[] filteredLoggingBehaviors = loggingBehaviorFilter(loggingBehaviors, methodName);

            // Enable valid arguments.
            for (String filteredLoggingBehavior : filteredLoggingBehaviors) {

                // TODO: TEST THIS!
                switch (LuaFBLoggingBehavior.valueOf(filteredLoggingBehavior)) {
                    case ACCESS_TOKENS:
                        FacebookSdk.addLoggingBehavior(LoggingBehavior.INCLUDE_ACCESS_TOKENS);
                        break;
                    case APP_EVENTS:
                        FacebookSdk.addLoggingBehavior(LoggingBehavior.APP_EVENTS);
                        break;
                    case CACHE:
                        FacebookSdk.addLoggingBehavior(LoggingBehavior.CACHE);
                        break;
                    case GRAPH_API_DEBUG_WARNING:
                        FacebookSdk.addLoggingBehavior(LoggingBehavior.GRAPH_API_DEBUG_WARNING);
                        break;
                    case GRAPH_API_DEBUG_INFO:
                        FacebookSdk.addLoggingBehavior(LoggingBehavior.GRAPH_API_DEBUG_INFO);
                        break;
                    case NETWORK_REQUESTS:
                        FacebookSdk.addLoggingBehavior(LoggingBehavior.INCLUDE_RAW_RESPONSES);
                        FacebookSdk.addLoggingBehavior(LoggingBehavior.REQUESTS);
                        break;
                    case PLUGIN_AND_FACEBOOK_SDK_COMMUNICATION:
                        // TODO
                        break;
                    default:
                        break;
                }
            }
        }
    }

    /**
     * facebook.getCurrentAccessToken entry point
     */
    public static int facebookGetCurrentAccessToken() {
        // Grab the method name for error messages:
        String methodName = "FacebookController.facebookGetCurrentAccessToken()";
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

		LuaState L = fetchLuaState();
		if (L == null) {
			Log.i("Corona", "ERROR: " + methodName + NO_LUA_STATE_ERR_MSG);
			return 0;
		}

		AccessToken currentAccessToken = AccessToken.getCurrentAccessToken();
		if (currentAccessToken != null) {
			// Table of access token data to be returned
			L.newTable(0, 7);

			// Token string - like in fbconnect event
			L.pushString(currentAccessToken.getToken());
			L.setField(-2, "token");

			// Expiration date - like in fbconnect event
			L.pushNumber(toSecondsFromMilliseconds(currentAccessToken.getExpires().getTime()));
			L.setField(-2, "expiration");

			// Refresh date
			L.pushNumber(toSecondsFromMilliseconds(currentAccessToken.getLastRefresh().getTime()));
			L.setField(-2, "lastRefreshed");

			// App Id
			L.pushString(currentAccessToken.getApplicationId());
			L.setField(-2, "appId");

			// User Id
			L.pushString(currentAccessToken.getUserId());
			L.setField(-2, "userId");

			// Granted permissions
			Object[] grantedPermissions = currentAccessToken.getPermissions().toArray();
			if (createLuaTableFromStringArray(Arrays.copyOf(
							grantedPermissions, grantedPermissions.length, String[].class)) > 0) {

				// Assign the granted permissions table to the access token table,
				// which is now 2nd from the top of the stack.
				L.setField(-2, "grantedPermissions");
							}

			// Declined permissions
			Object[] declinedPermissions =
				currentAccessToken.getDeclinedPermissions().toArray();
			if (createLuaTableFromStringArray(Arrays.copyOf(
							declinedPermissions, declinedPermissions.length, String[].class)) > 0) {

				// Assign the declined permissions table to the access token table,
				// which is now 2nd from the top of the stack.
				L.setField(-2, "declinedPermissions");
							}

			// Now our table of access token data is at the top of the stack
		} else {
			// Return nil
			L.pushNil();
		}

        return 1;
    }

    /**
     * facebook.isFacebookAppEnabled() entry point
     * Determines if the Facebook (or Facebook Lite) App is installed
     */
    public static boolean facebookIsFacebookAppEnabled() {

        // Invoke PackageServices for both the Facebook and Facebook Lite app
        PackageServices packageServices =
                new PackageServices(CoronaEnvironment.getApplicationContext());
        PackageState facebookAppPackageState = packageServices.getPackageState(
                "com.facebook.katana", PackageManager.GET_ACTIVITIES);
        PackageState facebookLitePackageState = packageServices.getPackageState(
                "com.facebook.lite", PackageManager.GET_ACTIVITIES);

        return facebookAppPackageState == PackageState.ENABLED ||
                facebookLitePackageState == PackageState.ENABLED;

    }

    /**
     * facebook.login() entry point
     * @param permissions: An array of permissions to be requested if needed.
     */
    public static void facebookLogin(String permissions[]) {
        // Grab the method name for error messages:
        String methodName = "FacebookController.facebookLogin()";
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

        if (permissions == null) {
            Log.i("Corona", "ERROR: " + methodName + ": Can't set permissions to null! " +
                    "Be sure to pass in an initialized array of permissions.");
        } else if (permissions.length == 0) {
            loginWithOnlyRequiredPermissions();
        } else {
            // We want to request some extended permissions.
            requestPermissions(permissions);
        }
    }

    private static class FacebookActivityResultHandler
            implements CoronaActivity.OnActivityResultHandler {
        @Override
        public void onHandleActivityResult(CoronaActivity activity, int requestCode,
                                           int resultCode, Intent data)
        {
            // Grab the method name for error messages:
            String methodName = "FacebookController." +
                    "FacebookActivityResultHandler.onHandleActivityResult()";
			if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

            if (sCallbackManager != null) {
                sCallbackManager.onActivityResult(requestCode, resultCode, data);
            }
            else {
                Log.i("Corona", "ERROR: " + methodName + ": Facebook's Callback manager isn't " +
                        "initialized. Be sure to initialize the callback manager before the " +
                        "FacebookActivityResultHandler is called.");
            }
        }
    }

    /**
     * facebook.logout() entry point
     * Logs out of facebook from the app.
     * This will not also log off the facebook app if it's installed.
     * Since login will grab info from the Facebook app if installed,
     * this means that logging back in will grab that info.
     * In the case of the Facebook app being installed, logout won't actually work because of this.
     * Users will need to log out from the Facebook App.
     * TODO: Add this to documentation, and have a way to have
     * facebook.logout() work with Facebook App installed if possible.
     */
    public static void facebookLogout() {
        // Grab the method name for error messages:
        String methodName = "FacebookController.facebookLogout()";
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

        LoginManager.getInstance().logOut();

        dispatchLoginFBConnectTask(methodName, FBLoginEvent.Phase.logout, null, 0);
    }

    /**
     * facebook.request() entry point
     * @param path: Graph API path
     * @param method: HTTP method to use for the request, "GET", "POST", or "DELETE"
     * @param params: Arguments for Graph API request
     */
    public static void facebookRequest( String path, String method, Hashtable params ) {
        // Grab the method name for error messages:
        String methodName = "FacebookController.facebookRequest";
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName + "(" + path + ", " + method + ", " + params.toString() + ")" );

        AccessToken currentAccessToken = AccessToken.getCurrentAccessToken();

        if (currentAccessToken != null) {

            // Verify params and environment
            CoronaActivity activity = CoronaEnvironment.getCoronaActivity();
            if (activity == null) {
                Log.i("Corona", "ERROR: " + methodName + NO_ACTIVITY_ERR_MSG);
                return;
            }

            // Figure out what type of request to make
            HttpMethod httpMethod = HttpMethod.valueOf(method);
            if (httpMethod != HttpMethod.GET
                    && httpMethod != HttpMethod.POST
                    && httpMethod != HttpMethod.DELETE) {
                Log.i("Corona", "ERROR: " + methodName + ": only supports " +
                        "HttpMethods GET, POST, and DELETE! Cancelling request.");
                return;
            }

            // Use the most universal method for requests vs Facebook's very-specific request APIs
            final GraphRequest finalRequest = new GraphRequest(
                    currentAccessToken,
                    path,
                    createFacebookBundle(params),
                    HttpMethod.valueOf(method),
                    new FacebookRequestCallbackListener());

            // The facebook documentation says this should only be run on the UI thread
            activity.runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    finalRequest.executeAsync();
                }
            });
        } else {
            // Can't perform a Graph Request without being logged in.
            // TODO: Log the user in, and then retry the same Graph API request.
            Log.i("Corona", "ERROR: " + methodName + ": cannot process a Graph API request " +
                    "without being logged in. Please call facebook.login() before calling " +
                    "facebook.request()." );
        }
    }

    private static class FacebookRequestCallbackListener implements GraphRequest.Callback {
        @Override
        public void onCompleted(GraphResponse response)
        {
            // Grab the method name for error messages:
            String methodName = "FacebookController.FacebookRequestCallbackListener.onCompleted()";
			if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

            // Create local reference to sCoronaRuntime and null check it to guard against
            // the possibility of a separate thread nulling out sCoronaRuntime, say if the
            // Activity got destroyed.
            CoronaRuntime runtime = sCoronaRuntime;
            if (runtime == null) {
                // Log.i("Corona", "ERROR: " + methodName + NO_RUNTIME_ERR_MSG);
                return;
            }

            if (runtime.isRunning() && response != null) {
                if (response.getError() != null) {
                    runtime.getTaskDispatcher().send(new FBConnectTask(sListener,
                            response.getError().getErrorMessage(), true));
                } else {
                    String message = "";
                    if (response.getJSONObject() != null &&
                            response.getJSONObject().toString() != null) {
                        message = response.getJSONObject().toString();
                    } else {
                        Log.i("Corona", "ERROR: " + methodName +
                                ": could not parse the response from Facebook");
                    }
                    runtime.getTaskDispatcher().send(new FBConnectTask(sListener, message, false));
                }

            } else if (response == null) {
                Log.i("Corona", "ERROR: " + methodName +
                        ": could not send a response because Facebook didn't give a response");
            }
        }
    }

    /**
     * facebook.showDialog() entry point
     * @param action: The type of dialog to open
     * @param params: Table of arguments to the desired dialog
     *
     * TODO: Refactor some of the individual share dialogs to their own functions.
     */
    public static void facebookDialog( final String action, final Hashtable params ) {

        // Grab the method name for error messages:
        final String methodName = "FacebookController.facebookDialog()";
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

        // Verify params and environment
        final CoronaActivity activity = CoronaEnvironment.getCoronaActivity();
        if (activity == null) {
            Log.i("Corona", "ERROR: " + methodName + NO_ACTIVITY_ERR_MSG);
            return;
        }

		// This is out here so that the listener won't disappear while on the other thread
		int listener = -1;
		LuaState L = fetchLuaState();
		if (L != null && CoronaLua.isListener(L, -1, "")) {
			listener = CoronaLua.newRef(L, -1);
		} else if (L == null) {
			Log.i("Corona", "ERROR: " + methodName + NO_LUA_STATE_ERR_MSG);
			return;
		}

        final int finalListener = listener;

        // Do UI things on UI thread
        activity.runOnUiThread(new Runnable() {
                                   @Override
                                   public void run() {

                                       if (isShareAction(action)) {
                                           // Grab the base share parameters -- those defined in ShareContent.java
                                           // TODO: SUPPORT SHAREHASHTAG
                                           String contentUrl = params != null ? (String) params.get("link") : null;
                                           LinkedList<String> peopleIds = null;
                                           Hashtable peopleIdsTable =
                                                   params != null ? (Hashtable) params.get("peopleIds") : null;
                                           if (peopleIdsTable != null) {
                                               peopleIds = new LinkedList(peopleIdsTable.values());
                                           }
                                           String placeId = params != null ? (String) params.get("placeId") : null;
                                           String ref = params != null ? (String) params.get("ref") : null;

                                           if (action.equals("feed") || action.equals("link")) {

                                               // "link" uses Facebook's default settings which depends on the presence
                                               // of the Facebook app on the device.

                                               // Validate data
                                               // Get the Uris that we can parse
                                               Uri linkUri = null;
                                               if (contentUrl != null) {
                                                   linkUri = Uri.parse(contentUrl);
                                               } else {
                                                   Log.i("Corona", "ERROR: " + methodName
                                                           + INVALID_PARAMS_SHOW_DIALOG_ERR_MSG
                                                           + " options.link is required");
                                               }

                                               String photoUrl = params != null ? (String) params.get("picture") : null;
                                               Uri photoUri = null;
                                               if (photoUrl != null) {
                                                   photoUri = Uri.parse(photoUrl);
                                               }

                                               // Grab remaining link data
                                               String description =
                                                       params != null ? (String) params.get("description") : null;
                                               String name = params != null ? (String) params.get("name") : null;

                                               // Set up the dialog to share this link
                                               if (action.equals("feed")) { // Use the ShareFeedContent internal class.
                                                   ShareFeedContent feedContent = new ShareFeedContent.Builder()
                                                           .setLinkDescription(description)
                                                           .setLinkName(name)
                                                           .setPicture(photoUrl)
                                                           .setContentUrl(linkUri)
                                                           .setPeopleIds(peopleIds)
                                                           .setPlaceId(placeId)
                                                           .setRef(ref)
                                                           .build();
                                                   // Present the dialog through the old Feed dialog.
                                                   sShareDialog.show(feedContent, ShareDialog.Mode.FEED);
                                               } else { // Use the regular ShareLinkContent class.
                                                   ShareLinkContent linkContent = new ShareLinkContent.Builder()
//                                                           .setContentDescription(description)
//                                                           .setContentTitle(name)
//                                                           .setImageUrl(photoUri)
                                                           .setQuote(description)
                                                           .setContentUrl(linkUri)
                                                           .setPeopleIds(peopleIds)
                                                           .setPlaceId(placeId)
                                                           .setRef(ref)
                                                           .build();

                                                   // Presenting the share dialog behaves differently depending on whether
                                                   // the user has the Facebook app installed on their device or not. With
                                                   // the Facebook app, things like tagging friends and a location are
                                                   // built-in. Otherwise, these things aren't built-in.
                                                   sShareDialog.show(linkContent);
                                               }
                                           } else if (action.equals("photo")) {
                        /* TODO: For sharing photos from device, Support loading bitmaps from app - Added in SDK 4+
                        * TODO: For sharing photos from device, Check if image is 200x200
                                * TODO: For sharing photos from device, have it work without FB app,
                        *       SharePhoto only works with Facebook app according to:
                        *       http://stackoverflow.com/questions/30843786/sharing-photo-using-facebook-sdk-4-2-0
                        */
                                               // Ensure that the environment is right for sharing a photo.
                                               if (!facebookIsFacebookAppEnabled()) {
                                                   // TODO: Just throw an error or redirect people to the store?
                                                   Log.i("Corona", "ERROR: Facebook app isn't installed for sharing photos.");
                                               } else {
                                                   // Grab all the photo data provided in Lua.
                                                   LinkedList<Hashtable> photosDataFromLua = null;
                                                   Hashtable photosLuaTable =
                                                           params != null ? (Hashtable) params.get("photos") : null;
                                                   if (photosLuaTable != null) {
                                                       photosDataFromLua = new LinkedList(photosLuaTable.values());
                                                   } // else, no photos table was provided

                                                   if (photosDataFromLua != null) {

                                                       // Create SharePhoto objects from all the provided photo data.
                                                       LinkedList<SharePhoto> sharePhotosList =
                                                               new LinkedList<SharePhoto>();
                                                       for (Hashtable photoData : photosDataFromLua) {
                                                           // Caption for the photo.
                                                           // Note that the 'caption' must come from the user,
                                                           // as pre-filled content is forbidden by the
                                                           // Platform Policies (2.3). This makes the parameter useless,
                                                           // but we have it implemented (and undocumented should the
                                                           // Platform Policies change)
                                                           String caption = photoData != null ?
                                                                   (String) photoData.get("caption") : null;

                                                           // URL for the photo.
                                                           String photoUrl =
                                                                   photoData != null ? (String) photoData.get("url") : null;
                                                           Uri photoUri = null;
                                                           if (photoUrl != null) {
                                                               photoUri = Uri.parse(photoUrl);
                                                           }

                                                           // Make the SharePhoto and add it to the list.
                                                           SharePhoto sharePhoto = new SharePhoto.Builder()
                                                                   .setCaption(caption)
                                                                   .setImageUrl(photoUri)
                                                                   .build();
                                                           sharePhotosList.add(sharePhoto);
                                                       }

                                                       // Create the SharePhotoContent and present the dialog
                                                       SharePhotoContent sharePhotoContent = new SharePhotoContent.Builder()
                                                               .addPhotos(sharePhotosList)
                                                               .build();

                                                       // Change the dialog mode so that we can share online images without changing the Corona core.
                                                       // This is the default behavior with the Facebook Lite app installed.
                                                       sShareDialog.show(sharePhotoContent, ShareDialog.Mode.WEB);
                                                   } // else, an empty photos table was provided
                                               }
                                           }
                                       } else if (action.equals("requests") || action.equals("apprequests")) {

                                           // Grab game request-specific data
                                           // Parse simple options
                                           String message = params != null ? (String) params.get("message") : null;
                                           String to = params != null ? (String) params.get("to") : null;
                                           String data = params != null ? (String) params.get("data") : null;
                                           String title = params != null ? (String) params.get("title") : null;
                                           String objectId = params != null ? (String) params.get("objectId") : null;

                                           // Parse complex options
                                           // ActionType
                                           ActionType actionType = null;
                                           Object actionTypeObject = params != null ? params.get("actionType") : null;
                                           if (actionTypeObject instanceof String) {
                                               actionType = enumValueOfIgnoreCase
                                                       (ActionType.class, (String) actionTypeObject);
                                           } else if (actionTypeObject != null) {
                                               Log.i("Corona", "ERROR: " + methodName +
                                                       INVALID_PARAMS_SHOW_DIALOG_ERR_MSG +
                                                       " options.actionType must be a string");
                                               return;
                                           }

                                           // Filter
                                           // This is an enum that contains filters for which groups of friends to show on
                                           // the Game Request dialog. Unfortunately, facebook gave this enum the name
                                           // "Filters" on Android, so the code is a little difficult to understand.
                                           Filters filter = null;
                                           Object filterObject = params != null ? params.get("filter") : null;
                                           if (filterObject instanceof String) {
                                               filter = enumValueOfIgnoreCase
                                                       (Filters.class, (String) filterObject);
                                           } else if (filterObject != null) {
                                               Log.i("Corona", "ERROR: " + methodName +
                                                       INVALID_PARAMS_SHOW_DIALOG_ERR_MSG +
                                                       " options.filter must be a string");
                                               return;
                                           }

                                           // Suggestions
                                           ArrayList suggestions = null;
                                           Hashtable suggestionsTable =
                                                   params != null ? (Hashtable) params.get("suggestions") : null;
                                           if (suggestionsTable != null) {
                                               Collection suggestionsCollection = suggestionsTable.values();

                                               // Purge for malformed data in the "suggestions" table.
                                               // Throw an error to the developer if we find any.
                                               for (Object suggestion : suggestionsCollection) {
                                                   if (!(suggestion instanceof String) ||
                                                           !((String) suggestion).matches("[0-9]+")) {
                                                       Log.i("Corona", "ERROR: " + methodName +
                                                               INVALID_PARAMS_SHOW_DIALOG_ERR_MSG +
                                                               " options.suggestions must contain Facebook User IDs as " +
                                                               "strings");
                                                       return;
                                                   }
                                               }

                                               // Convert the data to the right format now that it's been verified.
                                               suggestions = new ArrayList(suggestionsCollection);
                                           }

                                           // Convert the "to" parameter to a list as it was deprecated as of
                                           // Facebook SDK v4.7.0.
                                           ArrayList<String> recipients = null;
                                           if (to != null) {
                                               recipients = new ArrayList<>();
                                               recipients.add(to);
                                           }

                                           // Create a game request dialog
                                           // ONLY WORKS IF YOUR APP IS CATEGORIZED AS A GAME IN FACEBOOK DEV PORTAL
                                           GameRequestContent requestContent = new GameRequestContent.Builder()
                                                   .setMessage(message)
                                                   .setRecipients(recipients)
                                                   .setData(data)
                                                   .setTitle(title)
                                                   .setActionType(actionType)
                                                   .setObjectId(objectId)
                                                   .setFilters(filter)
                                                   .setSuggestions(suggestions)
                                                   .build();

                                           sRequestDialog.show(requestContent);
                } else //noinspection StatementWithEmptyBody
                    if (action.equals("place") || action.equals("friends")) {
                    // There are no facebook dialog for these
                    sPlacesOrFriendsIntent = new Intent(activity, FacebookFragmentActivity.class);
                    sPlacesOrFriendsIntent.putExtra(FacebookFragmentActivity.FRAGMENT_NAME, action);
                    sPlacesOrFriendsIntent.putExtra(FacebookFragmentActivity.FRAGMENT_LISTENER,
                            finalListener);
                    sPlacesOrFriendsIntent.putExtra(FacebookFragmentActivity.FRAGMENT_EXTRAS,
                            createFacebookBundle(params));
                    // Handle location permission for places
                    if (action.equals("place")) {
                        switch (sPermissionsServices.getPermissionStateForSupportedGroup(
                                PermissionsServices.PermissionGroup.LOCATION)) {
                            case DENIED:
                                if (android.os.Build.VERSION.SDK_INT >= 23) {
                                    requestLocationPermission();
                                } // Otherwise, the OS has denied us Location permission.
                                break;
                            case MISSING:
                                // We can uses "Facebook Places" without Location permission.
                                // It just won't work as well.
                            default:
                                // Granted. Move on.
                                activity.startActivity(sPlacesOrFriendsIntent);
                                break;
                        }
                    } else {
                        activity.startActivity(sPlacesOrFriendsIntent);
                    }
                } else {
//            // TODO: Figure out what happens here since the WebDialog flow no longer applies.
//            // This would probably be the open graph case, like this GoT example
//            // Create an object
//            ShareOpenGraphObject object = new ShareOpenGraphObject.Builder()
//                    .putString("og:type", "books.book")
//                    .putString("og:title", "A Game of Thrones")
//                    .putString("og:description", "In the frozen wastes to the north of " +
//                    "Winterfell, sinister and supernatural forces are mustering.")
//                    .putString("books:isbn", "0-553-57340-3")
//                    .build();
//            // Create an action
//            ShareOpenGraphAction action = new ShareOpenGraphAction.Builder()
//                    .setActionType("books.reads")
//                    .putObject("book", object)
//                    .build();
//            // Create the content
//            ShareOpenGraphContent content = new ShareOpenGraphContent.Builder()
//                    .setPreviewPropertyName("book")
//                    .setAction(action)
//                    .build();
//            sShareDialog.show(content);
                }
            }
        });
    }

    /** Default handling of the location permission for Facebook Places on Android 6+. */
    private static class LocationRequestPermissionsResultHandler
            implements CoronaActivity.OnRequestPermissionsResultHandler {

        @Override
        public void onHandleRequestPermissionsResult(
                CoronaActivity activity, int requestCode, String[] permissions, int[] grantResults)
        {
            PermissionsSettings permissionsSettings =
                    activity.unregisterRequestPermissionsResultHandler(this);

            if (permissionsSettings != null) {
                permissionsSettings.markAsServiced();
            }

            // Move on to Facebook places regardless of the state of the Location permission.
            // We do this because the Location permission is optional.
            activity.startActivity(sPlacesOrFriendsIntent);
        }
    }

    /**
     * facebook.publishInstall() entry point
     */
    public static void publishInstall() {
        // Grab the method name for error messages:
        String methodName = "FacebookController.publishInstall()";
		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );

        CoronaActivity activity = CoronaEnvironment.getCoronaActivity();
        if (activity == null) {
            Log.i("Corona", "ERROR: " + methodName + NO_ACTIVITY_ERR_MSG);
            return;
        }

        AppEventsLogger.activateApp(activity.getApplication());
    }

    /**
     * facebook.setFBConnectListener entry point
     * @param listener: This listener to be called from the Facebook-v4a plugin
     */
    public static void setFBConnectListener(int listener) {
        sListener = listener;
    }

    /**
     * facebook.setFBInitListener entry point
     * @param listener: listener to be called from the Facebook-v4a plugin when initialization completes
     */
    public static void setFBInitListener(int listener) {
		final String methodName = "FacebookController.setFBInitListener()";

		if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName );
        sInitListener = listener;

		// default the FBConnectListener to this one
		if (sListener != listener) {
			sListener = listener;
		}

		// If we've already initialized, send the event now
		if (finishedFBSDKInit.get()) {
			if (Rtt_DEBUG) Log.i("Corona", "++++++++++: " + methodName + ": already initialized" );

			dispatchFBInitEvent(methodName);
		}
    }

   public static String getThreadSignature()
   {
      Thread t = Thread.currentThread();
      long l = t.getId();
      String name = t.getName();
      long p = t.getPriority();
      String gname = t.getThreadGroup().getName();
      return ("Thread: " + name
            + " (id:" + l
            + ", priority: " + p
            + ", group: " + gname);
   }

   public static void logThreadSignature(String mesg)
   {
      if (Rtt_DEBUG) Log.d("Corona", mesg + ": " + getThreadSignature());
   }
}
