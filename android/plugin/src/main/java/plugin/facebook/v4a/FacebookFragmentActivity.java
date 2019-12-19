//
//  FacebookFragmentActivity.java
//  Facebook-v4a Plugin
//
//  Copyright (c) 2015 Corona Labs Inc. All rights reserved.
//

package plugin.facebook.v4a;

import android.annotation.SuppressLint;
import android.content.Context;
import android.location.Criteria;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.os.Looper;
import android.support.v4.app.FragmentActivity;
import android.support.v4.app.FragmentTransaction;
import android.util.Log;
import android.view.ViewGroup.LayoutParams;
import android.view.inputmethod.InputMethodManager;
import android.widget.FrameLayout;

import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeTask;
import picker.FriendPickerFragment;
import picker.PickerFragment;
import picker.PlacePickerFragment;
import com.naef.jnlua.LuaState;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Iterator;
import java.util.List;

// Pickers classes have been ported back to Facebook SDK 4+ by Corona

@SuppressLint("Registered")
public class FacebookFragmentActivity extends FragmentActivity {
	/************************************** Member Variables **************************************/
	public static final String FRAGMENT_NAME = "fragment_name";
	public static final String FRAGMENT_LISTENER = "fragment_listener";
	public static final String FRAGMENT_EXTRAS = "fragment_extras";

	// From PickerActivity.java in Facebook SDK 4+
	private static final int LOCATION_CHANGE_THRESHOLD = 50; // meters

	// TODO: NOT INCLUDE THIS RES ID EXPLICITLY LIKE THIS.
	private static final int CONTENT_VIEW_ID = 192875;
	private PickerFragment mFragment;
	private int mListener;
	private String mFragmentToLaunch;
	private Location mLocation = null;
	private LocationListener mLocationListener;
	/**********************************************************************************************/
	/********************************** Utility Functions *****************************************/
	private void printIllegalFragmentTypeMessage(String fromMethod) {
		Log.i("Corona", "ERROR: " + fromMethod + ": can't launch Fragment " + mFragmentToLaunch +
				". Acceptable fragment types are: \"place\" and \"friends\"");
	}

	private void pushStringIfNotNull(LuaState L, String pushString, String field) {
		if (pushString != null) {
			L.pushString(pushString);
			L.setField(-2, field);
		}
	}

	private void pushFriendSelection(final List<JSONObject> friendsSelection) {
		CoronaRuntimeTask task = new CoronaRuntimeTask() {
			@Override
			public void executeUsing(CoronaRuntime runtime) {
				if (runtime != null && friendsSelection != null && mListener>0) {
					LuaState L = runtime.getLuaState();
					if (L != null) {
						CoronaLua.newEvent( L, "friends");
						Iterator<JSONObject> iterator = friendsSelection.iterator();

						// event.data
						L.newTable(0, friendsSelection.size());

						JSONObject graphUser;
						int index = 1;
						while(iterator.hasNext()) {
							graphUser = iterator.next();
							pushGraphUser(L, graphUser, index);
							index++;
						}

						L.setField(-2, "data");

						try {
							CoronaLua.dispatchEvent( L, mListener, 0 );
							CoronaLua.deleteRef(L, mListener);
						} catch (Exception e) {
							Log.e("Corona", "Facebook pushFriendSelection: failed to dispatch event", e);
						}
					}
				}
			}

			private void pushGraphUser(LuaState L, JSONObject graphUser, int index) {
				L.newTable(0, 4);

				// This is so we can push the proper data to Lua
				// Facebook SDK 4+, doesn't have First or Last name fields unlike previous versions
				try {
					pushStringIfNotNull(L, graphUser.getString("name"), "fullName");
					pushStringIfNotNull(L, graphUser.getString("id"), "id");
				} catch (JSONException e) {
					Log.e("Corona", "Facebook pushGraphUser: JSON error", e);
				}
				L.rawSet(-2, index);
			}
		};
		CoronaEnvironment.getCoronaActivity().getRuntimeTaskDispatcher().send(task);
	}

	private void pushPlaceSelection(final JSONObject placeSelection) {
		CoronaRuntimeTask task = new CoronaRuntimeTask() {
			@Override
			public void executeUsing(CoronaRuntime runtime) {
				if (runtime != null && placeSelection != null && mListener>0) {
					LuaState L = runtime.getLuaState();
					if (L != null) {
						CoronaLua.newEvent(L, "place");

						// event.data
						L.newTable(0, 11);

						// This is so we can push the proper data to Lua
						try {
							pushStringIfNotNull(L,
									placeSelection.getString("category"), "category");
							pushStringIfNotNull(L, placeSelection.getString("id"), "id");
							pushStringIfNotNull(L, placeSelection.getString("name"), "name");

							JSONObject location = placeSelection.getJSONObject("location");
							if (location != null) {

								pushStringIfNotNull(L, location.getString("city"), "city");
								pushStringIfNotNull(L, location.getString("country"), "country");
								pushStringIfNotNull(L, location.getString("state"), "state");
								pushStringIfNotNull(L, location.getString("street"), "street");
								pushStringIfNotNull(L, location.getString("zip"), "zip");

								L.pushNumber(location.getDouble("latitude"));
								L.setField(-2, "latitude");

								L.pushNumber(location.getDouble("longitude"));
								L.setField(-2, "longitude");
							}
						} catch (JSONException e) {
							Log.e("Corona", "Facebook pushPlaceSelection: JSON error", e);
						}

						L.setField(-2, "data");

						try {
							CoronaLua.dispatchEvent( L, mListener, 0 );
							CoronaLua.deleteRef(L, mListener);
						} catch (Exception e) {
							Log.e("Corona", "Facebook pushPlaceSelection: failed to dispatch event", e);
						}
					}
				}
			}
		};
		CoronaEnvironment.getCoronaActivity().getRuntimeTaskDispatcher().send(task);
	}
	/**********************************************************************************************/
	/****************************** FragmentActivity Overrides ************************************/
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		// Grab the method name for error messages:
		String methodName = "FacebookFragmentActivity.onCreate()";

		FrameLayout frame = new FrameLayout(this);
		frame.setId(CONTENT_VIEW_ID);
		setContentView(frame, new LayoutParams(
				LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));

		mFragmentToLaunch = getIntent().getExtras().getString(FRAGMENT_NAME);
		mListener = getIntent().getExtras().getInt(FRAGMENT_LISTENER);

		Bundle extraInfo = getIntent().getBundleExtra(FRAGMENT_EXTRAS);

		mFragment = null;
		switch (mFragmentToLaunch) {
			case "place":
				PlacePickerFragment placePicker = new PlacePickerFragment();
				mFragment = placePicker;

				String titleText = extraInfo.getString("title");
				if (titleText != null) {
					placePicker.setTitleText(titleText);
				}

				String searchText = extraInfo.getString("searchText");
				if (searchText != null) {
					placePicker.setSearchText(searchText);
				}

				String latitude = extraInfo.getString("latitude");
				String longitude = extraInfo.getString("longitude");
				if (latitude != null && longitude != null) {
					mLocation = new Location(LocationManager.PASSIVE_PROVIDER);
					try {
						mLocation.setLatitude(Double.parseDouble(latitude));
						mLocation.setLongitude(Double.parseDouble(longitude));
						placePicker.setLocation(mLocation);
					} catch (NumberFormatException e) {
						Log.e("Corona", methodName + ": failed to parse lat/long", e);
					}
				}

				String resultsLimit = extraInfo.getString("resultsLimit");
				if (resultsLimit != null) {
					try {
						placePicker.setResultsLimit(Double.valueOf(resultsLimit).intValue());
					} catch (NumberFormatException e) {
						Log.e("Corona", methodName + ": failed to set resultsLimit", e);
					}
				}

				String radiusInMeters = extraInfo.getString("radiusInMeters");
				if (radiusInMeters != null) {
					try {
						placePicker.setRadiusInMeters(Double.valueOf(radiusInMeters).intValue());
					} catch (NumberFormatException e) {
						Log.e("Corona", methodName + ": failed to set radiusInMeters", e);
					}
				}

				placePicker.setOnSelectionChangedListener(
						new PickerFragment.OnSelectionChangedListener() {
							@Override
							// You can only pick 1 location so we can finish right after its picked
							public void onSelectionChanged(PickerFragment fragment) {
								JSONObject graphPlace = ((PlacePickerFragment) fragment).getSelection();
								if (graphPlace != null) {
									pushPlaceSelection(graphPlace);
								}

								InputMethodManager imm = (InputMethodManager) getSystemService(
										Context.INPUT_METHOD_SERVICE);
								imm.hideSoftInputFromWindow(fragment.getActivity()
										.getWindow().getDecorView().getApplicationWindowToken(), 0);

								finish();
							}
						});
				placePicker.setOnDoneButtonClickedListener(
						new PickerFragment.OnDoneButtonClickedListener() {
							@Override
							public void onDoneButtonClicked(PickerFragment fragment) {
								JSONObject graphPlace = ((PlacePickerFragment) fragment).getSelection();
								if (graphPlace != null) {
									pushPlaceSelection(graphPlace);
								}

								InputMethodManager imm = (InputMethodManager) getSystemService(
										Context.INPUT_METHOD_SERVICE);
								imm.hideSoftInputFromWindow(fragment.getActivity()
										.getWindow().getDecorView().getApplicationWindowToken(), 0);

								finish();
							}
						});

				break;
			case "friends":
				mFragment = new FriendPickerFragment();
				FriendPickerFragment friendPickerFragment = (FriendPickerFragment) mFragment;
				friendPickerFragment.setFriendPickerType(
						FriendPickerFragment.FriendPickerType.TAGGABLE_FRIENDS);
				friendPickerFragment.setOnDoneButtonClickedListener(
						new PickerFragment.OnDoneButtonClickedListener() {
							@Override
							public void onDoneButtonClicked(PickerFragment fragment) {
								// Does not return null so no need to do a null check
								List<JSONObject> friendsSelection =
										((FriendPickerFragment) fragment).getSelection();

								pushFriendSelection(friendsSelection);

								finish();
							}
						});
				break;
			default:
				printIllegalFragmentTypeMessage(methodName);
				return;
		}

		FragmentTransaction fragmentTransaction = getSupportFragmentManager().beginTransaction();
		fragmentTransaction.add(CONTENT_VIEW_ID, mFragment).commit();
	}

	@Override
	protected void onResume() {
		super.onResume();

		// Grab the method name for error messages:
		String methodName = "FacebookFragmentActivity.onResume()";

		try {

			switch (mFragmentToLaunch) {
				case "friends":
					// Load data, unless a query has already taken place.
					mFragment.loadData(false);
					break;
				case "place":
					// TODO: HANDLE LOCATION PERMISSIONS HERE AS SOMEONE COULD BE
					// RESUMING AFTER DISABLING LOCATION PERMISSIONS!
					// Based on PickerActivity.java in Facebook SDK 4.2.0 Scrumptious sample.
					Criteria criteria = new Criteria();
					LocationManager locationManager =
							(LocationManager) getSystemService(Context.LOCATION_SERVICE);
					String bestProvider = locationManager.getBestProvider(criteria, false);
					final PlacePickerFragment placePickerFragment = (PlacePickerFragment) mFragment;
					if (bestProvider != null) {
						mLocation = locationManager.getLastKnownLocation(bestProvider);
						if (locationManager.isProviderEnabled(bestProvider)) {
							if (mLocationListener == null) {
								mLocationListener = new LocationListener() {
									@Override
									public void onLocationChanged(Location location) {
										boolean updateLocation = true;
										Location prevLocation = placePickerFragment.getLocation();
										if (prevLocation != null) {
											updateLocation = location.distanceTo(prevLocation)
													>= LOCATION_CHANGE_THRESHOLD;
										}
										if (updateLocation) {
											placePickerFragment.setLocation(location);
											placePickerFragment.loadData(true);
										}
									}

									@Override
									public void onStatusChanged(String s, int i, Bundle bundle) {
									}

									@Override
									public void onProviderEnabled(String s) {
									}

									@Override
									public void onProviderDisabled(String s) {
									}
								};
							}

							locationManager.requestLocationUpdates(bestProvider, 1,
									LOCATION_CHANGE_THRESHOLD, mLocationListener,
									Looper.getMainLooper());
						} else {
							Log.i("Corona", "WARNING: " + methodName + ": is trying to use a " +
									"location provider that's disabled! Location services will " +
									"not be started.");
						}
					} else {
						Log.i("Corona", "WARNING: " + methodName + ": couldn't find a location " +
								"provider! Location services will not be started.");
					}

					if (mLocation != null) {
						placePickerFragment.setLocation(mLocation);
						placePickerFragment.loadData(false);
					} else {
						Log.i("Corona", "ERROR: " + methodName + ": doesn't have a starting location." +
								" Places Picker Fragment will not be shown.");
					}
					break;
				default:
					printIllegalFragmentTypeMessage(methodName);
					break;
			}
		} catch (Exception e) {
			Log.e("Corona", methodName + ": failed to resume", e);
		}
	}

	// Based on PickerActivity.java in Facebook SDK 4.2.0 Scrumptious sample.
	@Override
	protected void onPause() {
		super.onPause();

		// Stop taking location updates if applicable
		if (mLocationListener != null) {
			LocationManager locationManager =
					(LocationManager) getSystemService(Context.LOCATION_SERVICE);
			locationManager.removeUpdates(mLocationListener);
			mLocationListener = null;
		}
	}
}
