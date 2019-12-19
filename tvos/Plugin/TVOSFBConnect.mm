// ----------------------------------------------------------------------------
// 
// TVOSFBConnect.cpp
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// Reviewers:
// 		Walter
//
// ----------------------------------------------------------------------------

#include "TVOSFBConnect.h"

#include "CoronaAssert.h"
#include "CoronaLua.h"
#include "CoronaVersion.h"

#import "CoronaLuaIOS.h"
#import "CoronaRuntime.h"

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKTVOSKit/FBSDKTVOSKit.h>
#import <FBSDKShareKit/FBSDKShareKit.h>

//#import <Accounts/ACAccountStore.h>
//#import <Accounts/ACAccountType.h>

#import "CoronaDelegate.h"

// TVOSFBConnectDelegate
// ----------------------------------------------------------------------------
@interface TVOSFBConnectDelegate : NSObject< CoronaDelegate >
{
	NSString* urlPrefix;
	Corona::TVOSFBConnect *fOwner;
}

- (id)initWithOwner:(Corona::TVOSFBConnect*)owner;

@end


@implementation TVOSFBConnectDelegate

- (id)initWithOwner:(Corona::TVOSFBConnect*)owner
{
	urlPrefix = @"fbconnect://success?";
	
	self = [super init];
	if ( self )
	{
		fOwner = owner;
	}
	return self;
}

@end

// FBShareDelegate
// ----------------------------------------------------------------------------
@interface FBShareDelegate : TVOSFBConnectDelegate < FBSDKSharingDelegate >
@end


@implementation FBShareDelegate

// FBSDKSharingDelegate
// ----------------------------------------------------------------------------
- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary *)results
{
	// Need this to give a string in the following form to match Android:
	// fbconnect://success?PostID=10205888988338155_10206449924601211
	const char* urlResponse = [[NSString stringWithFormat:@"%@%@%@", urlPrefix, @"PostID=", [results objectForKey:@"postId"]] UTF8String];
	Corona::FBConnectDialogEvent e( urlResponse, false, true );
	fOwner->Dispatch( e );
}

- (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error
{
	Corona::FBConnectDialogEvent e( [[error localizedDescription] UTF8String], true, false );
	fOwner->Dispatch( e );
}

- (void)sharerDidCancel:(id<FBSDKSharing>)sharer
{
	Corona::FBConnectDialogEvent e( "Dialog was cancelled by user", false, false );
	fOwner->Dispatch( e );
}

@end

//// FBGameRequestDelegate
//// ----------------------------------------------------------------------------
//@interface FBGameRequestDelegate : TVOSFBConnectDelegate < FBSDKGameRequestDialogDelegate >
//@end
//
//
//@implementation FBGameRequestDelegate
//
//// FBSDKGameRequestDialogDelegate
//// ----------------------------------------------------------------------------
//- (void)gameRequestDialog:(FBSDKGameRequestDialog *)gameRequestDialog didCompleteWithResults:(NSDictionary *)results
//{
//	// Need this to give a string in the following form to match Android:
//	// fbconnect://success?RequestID=1074342222584935&Recipient=126305257702577
//	NSString *urlResponseString = [NSString stringWithFormat:@"%@%@%@", urlPrefix, @"RequestID=", [results objectForKey:@"request"]];
//	
//	// Get all recipients of the Game Request.
//	NSEnumerator *keyEnumerator = [results keyEnumerator];
//	NSString *recipient;
//	while ( ( recipient = [keyEnumerator nextObject] ) )
//	{
//		// Don't add the requestId again.
//		if ( [recipient isEqualToString:@"request"] ) continue;
//		
//		// Append this recipient
//		urlResponseString = [NSString stringWithFormat:@"%@%@%@", urlResponseString, @"&Recipient=", [results objectForKey:recipient]];
//	}
//	
//	const char* urlResponse = [urlResponseString UTF8String];
//	
//	Corona::FBConnectDialogEvent e( urlResponse, false, true );
//	fOwner->Dispatch( e );
//}
//
//- (void)gameRequestDialog:(FBSDKGameRequestDialog *)gameRequestDialog didFailWithError:(NSError *)error
//{
//	Corona::FBConnectDialogEvent e( [[error localizedDescription] UTF8String], true, false );
//	fOwner->Dispatch( e );
//}
//
//- (void)gameRequestDialogDidCancel:(FBSDKGameRequestDialog *)gameRequestDialog
//{
//	Corona::FBConnectDialogEvent e( "Dialog was cancelled by user", false, false );
//	fOwner->Dispatch( e );
//}
//
//@end
//
//// FBNoAppIdAlertDelegate
//// ----------------------------------------------------------------------------
//@interface FBNoAppIdAlertDelegate : NSObject< UIAlertViewDelegate >
//
//- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
//
//@end
//
//@implementation FBNoAppIdAlertDelegate
//
//- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
//{
//	switch( buttonIndex )
//	{
//		case 0: // Cancel button
//			break;
//		case 1: // Get App ID button
//			[[UIApplication sharedApplication] openURL:[[NSURL alloc] initWithString:@"https://developers.facebook.com/"]];
//			break;
//		case 2: // Integrate in Corona button
//			[[UIApplication sharedApplication] openURL:[[NSURL alloc] initWithString:@"https://docs.coronalabs.com/guide/social/implementFacebook/index.html#facebook"]];
//			break;
//		default:
//			break;
//	}
//	
//	// Exit the app so the developer can take care of the Facebook App ID.
//	exit(0);
//}
//
//@end
//// ----------------------------------------------------------------------------

#ifdef DEBUG_FACEBOOK_ENDPOINT

@interface TVOSFBConnectConnectionDelegate : NSObject
{
	NSMutableData *fData;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError*)error;

@end

@implementation TVOSFBConnectConnectionDelegate

- (id)init
{
	self = [super init];

	if ( self )
	{
		fData = [[NSMutableData alloc] init];
	}

	return self;
}

- (void)dealloc
{
	[fData release];
	[super dealloc];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	// This method is called incrementally as the server sends data; we must concatenate the data to assemble the response

	[fData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSMutableData *data = fData;
	NSString *filePath = NSTemporaryDirectory();

	// In the original test response, FB's server replied with a 1 pixel image (gif?)
	filePath = [filePath stringByAppendingPathComponent:@"a.gif"];

	if ( filePath )
	{
		[data writeToFile:filePath atomically:YES];
		NSLog( @"Outputing response to: %@.", filePath );
	}
}

- (void)connection:(NSURLConnection *)connection dispatchError:(NSString *)s
{
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response 
{
	// It can be called multiple times, for example in the case of a
	// redirect, so each time we reset the data.
	[fData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error 
{
	NSString *s = [error localizedDescription];
	[self connection:connection dispatchError:s];
}

@end

#endif // DEBUG_FACEBOOK_ENDPOINT

// ----------------------------------------------------------------------------

namespace Corona
{

// ----------------------------------------------------------------------------

FBConnect *
FBConnect::New( lua_State *L )
{
	void *platformContext = CoronaLuaGetContext( L ); // lua_touserdata( L, lua_upvalueindex( 1 ) );
	id<CoronaRuntime> runtime = (id<CoronaRuntime>)platformContext;
	
	return new TVOSFBConnect( runtime );
}

void
FBConnect::Delete( FBConnect *instance )
{
	delete instance;
}

// ----------------------------------------------------------------------------

const char TVOSFBConnect::kLostAccessTokenError[] = ": lost the access token. This could be the result of another thread completing facebook.logout() before this callback was invoked.";
	
//// Set up Enum - NSString conversion dictionaries.
//// From: http://stackoverflow.com/questions/13171907/best-way-to-enum-nsstring
//NSDictionary* TVOSFBConnect::FBSDKGameRequestActionTypeDictionary =
//  @{
//	@"none" : @(FBSDKGameRequestActionTypeNone),
//	@"send" : @(FBSDKGameRequestActionTypeSend),
//	@"askfor": @(FBSDKGameRequestActionTypeAskFor),
//	@"turn": @(FBSDKGameRequestActionTypeTurn)
//   };
//	
//NSDictionary* TVOSFBConnect::FBSDKGameRequestFilterDictionary =
//  @{
//	@"none" : @(FBSDKGameRequestFilterNone),
//	@"app_users" : @(FBSDKGameRequestFilterAppUsers),
//	@"app_non_users": @(FBSDKGameRequestFilterAppNonUsers)
//   };
	
	
TVOSFBConnect::TVOSFBConnect( id< CoronaRuntime > runtime )
:	Super(),
	fRuntime( runtime ),
	fHasObserver( false ),
//	fNoAppIdAlertDelegate( [[FBNoAppIdAlertDelegate alloc] init] ),
	fShareDialogDelegate( [[FBShareDelegate alloc] initWithOwner:this] ),
//	fGameRequestDialogDelegate( [[FBGameRequestDelegate alloc] initWithOwner:this] ),
//	fLoginManager( [[FBSDKLoginManager alloc] init] ),
//	fAccountStore( [[ACAccountStore alloc] init] ),
//	fFacebookAccountType( [fAccountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook] ),
#ifdef DEBUG_FACEBOOK_ENDPOINT
	fConnectionDelegate( [[TVOSFBConnectConnectionDelegate alloc] init] )
#else
	fConnectionDelegate( nil )
#endif
{
	// Grab the Facebook App ID from Info.plist
	// From: http://stackoverflow.com/questions/4059101/read-version-from-info-plist
	NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
	fFacebookAppId = [infoDict objectForKey:@"FacebookAppID"];
	// Throw an alert if there's no FacebookAppID. They screwed up the plist.
//	if ( ! fFacebookAppId )
//	{
//		UIAlertView *noAppIdAlert = [[UIAlertView alloc] initWithTitle:@"ERROR: Need Facebook App ID"
//														   message:@"To develop for Facebook Connect, you need to get a Facebook App ID and integrate it into your Corona project."
//														  delegate:fNoAppIdAlertDelegate
//												 cancelButtonTitle:@"Cancel"
//												 otherButtonTitles:@"Get App ID", @"Integrate in Corona", nil];
//		[noAppIdAlert show];
//	}
}

TVOSFBConnect::~TVOSFBConnect()
{
//	[fLoginManager release];
//	[fAccountStore release];
	[fNoAppIdAlertDelegate release];
	[fShareDialogDelegate release];
	[fGameRequestDialogDelegate release];
	[fConnectionDelegate release];
}

bool
TVOSFBConnect::Initialize( NSString *appId )
{
	const char functionName[] = "TVOSFBConnect::Initialize()";
	
	FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
	if ( accessToken.appID )
	{
		// Facebook wants us to add a POST so they can track which FB-enabled
		// apps use Corona:
		//
		//	HTTP POST to:
		//	https://www.facebook.com/impression.php
		//	Parameters:
		//	plugin = "featured_resources"
		//	payload = <JSON_ENCODED_DATA>
		//
		//	JSON_ENCODED_DATA
		//	resource "coronalabs_coronasdk"
		//	appid (Facebook app ID)
		//	version (This is whatever versioning string you attribute to your resource.)
		//
		CORONA_ASSERT( nil == appId || [appId isEqualToString:accessToken.appID] );

		NSString *format = @"{\"version\":\"%@\",\"resource\":\"coronalabs_coronasdk\",\"appid\":\"%@\"}";
		NSString *version = [NSString stringWithUTF8String:CoronaVersionBuildString()];
		NSString *json = [NSString stringWithFormat:format, version, accessToken.appID];
		NSString *post = [NSString stringWithFormat:@"plugin=featured_resources&payload=%@", json];
		NSString *postEscaped = [post stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		NSData *postData = [postEscaped dataUsingEncoding:NSUTF8StringEncoding];

		NSString *postLength = [NSString stringWithFormat:@"%ld", (unsigned long)[postData length]];

		NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] init] autorelease];
		NSURL *url = [NSURL URLWithString:@"https://www.facebook.com/impression.php"];
		[request setURL:url];
		[request setHTTPMethod:@"POST"];
		[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
		[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
		[request setTimeoutInterval:30];
		[request setHTTPBody:postData];

		NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:fConnectionDelegate];
		[connection start];
		[connection autorelease];
	}
	else
	{
		CORONA_LOG_WARNING( "%s%s", functionName, ": cannot allow Facebook to track this app since a Facebook App ID couldn't be found." );
	}

	return ( nil != accessToken );
}

void
TVOSFBConnect::LoginStateChanged( FBConnectLoginEvent::Phase state, NSError *error ) const
{
	const char functionName[] = "TVOSFBConnect::LoginStateChanged()";
	
	switch ( state )
	{
		case FBConnectLoginEvent::kLogin:
		{
			FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
			const_cast< Self * >( this )->Initialize( accessToken.appID );

			// Handle the logged in scenario
			// You may wish to show a logged in view
			NSString *token = accessToken.tokenString;
			NSDate *expiration = accessToken.expirationDate;
			FBConnectLoginEvent e( [token UTF8String], [expiration timeIntervalSince1970] );
			Dispatch( e );
			break;
		}

		case FBConnectLoginEvent::kLoginCancelled:
		case FBConnectLoginEvent::kLogout:
		{
			FBConnectLoginEvent e( state, NULL );
			Dispatch( e );
			break;
		}

		case FBConnectLoginEvent::kLoginFailed:
		{
			FBConnectLoginEvent e( state, [[error localizedDescription] UTF8String] );
			Dispatch( e );
			break;
		}

		default:
		{
			CORONA_LOG_ERROR( "%s%s", functionName, ": to an unknown state! Returning..." );
			break;
		}
	}
}

void
TVOSFBConnect::ReauthorizationCompleted( NSError *error ) const
{
	LoginStateChanged( ( error ? FBConnectLoginEvent::kLoginFailed : FBConnectLoginEvent::kLogin ), error );
}

void
TVOSFBConnect::Dispatch( const FBConnectEvent& e ) const
{
	e.Dispatch( fRuntime.L, GetListener() );
}

// Creates a Lua table out of an NSArray with NSStrings inside.
// Leaves the Lua table on top of the stack.
int
TVOSFBConnect::CreateLuaTableFromStringArray( lua_State *L, NSArray *array )
{
	const char functionName[] = "TVOSFBConnect::CreateLuaTableFromStringArray()";
	
	if ( ! array ) {
		CORONA_LOG_ERROR( "%s%s", functionName, ": cannot create a lua table from a nil array! Please pass in a non-nil string array.");
		return 0;
	}
	
	lua_createtable( L, (int)array.count, 0 );
	for (int i = 0; i < array.count; i++)
	{
		// Push this string to the top of the stack
		lua_pushstring( L, [array[i] UTF8String] );
		
		// Assign this string to the table 2nd from the top of the stack.
		// Lua arrays are 1-based so add 1 to index correctly.
		lua_rawseti( L, -2, i + 1 );
	}
	
	// Result is on top of the lua stack.
	return 1;
}

// This was brought up from the Facebook SDK (where it was private)
// and reimplemented to be more maintainable by Corona in the future
bool
TVOSFBConnect::IsPublishPermission( NSString *permission )
{
	return [permission hasPrefix:@"publish"] ||
	[permission hasPrefix:@"manage"] ||
	[permission isEqualToString:@"ads_management"] ||
	[permission isEqualToString:@"create_event"] ||
	[permission isEqualToString:@"rsvp_event"];
}
	
void
TVOSFBConnect::HandleRequestPermissionsResponse( NSArray *permissionsToVerify, FBSDKLoginManagerLoginResult *result, NSError *error ) const
{
	const char functionName[] = "TVOSFBConnect::HandleRequestPermissionsResponse()";
	
	if (result.isCancelled)
	{
		// The user cancelled out of the dialog requesting publish permissions
		LoginStateChanged( FBConnectLoginEvent::kLoginCancelled, nil );
	}
	else
	{
		FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
		if ( ! accessToken || // Should never happen if login was successful
			! [[result token] isEqualToAccessToken:accessToken] )
		{
			CORONA_LOG_ERROR( "%s%s", functionName, kLostAccessTokenError );
			return;
		}
		
		bool release = false;
		if ( ! error )
		{
			// Verify that all the requested permissions were granted
			for ( int i = 0; i < [permissionsToVerify count]; i++)
			{
				if ( ! [accessToken.permissions containsObject:[permissionsToVerify objectAtIndex:i]] )
				{
					release = true;
					error = [[NSError alloc] initWithDomain:@"com.facebook" code:123 userInfo:nil];
					break;
				}
			}
		}
		
		ReauthorizationCompleted(error);
		
		if ( release )
		{
			[error release];
		}
	}
}

bool
TVOSFBConnect::IsShareAction( NSString *action )
{
	return	[action isEqualToString:@"feed"] ||
			[action isEqualToString:@"link"] ||
			[action isEqualToString:@"photo"] ||
			[action isEqualToString:@"video"] ||
			[action isEqualToString:@"openGraph"];
}

//FBSDKGameRequestActionType
//TVOSFBConnect::GetActionTypeFrom( NSString* actionTypeString )
//{
//	id actionType = [FBSDKGameRequestActionTypeDictionary objectForKey:[actionTypeString lowercaseString]];
//	if ( actionType )
//	{
//		// Grab the value from the action type object, copy and return it.
//		return (FBSDKGameRequestActionType)[(NSNumber*)actionType intValue];
//	}
//	return FBSDKGameRequestActionTypeNone;
//}
//
//FBSDKGameRequestFilter
//TVOSFBConnect::GetFilterFrom( NSString* filterString )
//{
//	id filter = [FBSDKGameRequestFilterDictionary objectForKey:[filterString lowercaseString]];
//	if ( filter )
//	{
//		// Grab the value from the filter object, copy and return it.
//		return (FBSDKGameRequestFilter)[(NSNumber*)filter intValue];
//	}
//	return FBSDKGameRequestFilterNone;
//}
	
// Grabs the current access token from Facebook and converts it to a Lua table
int
TVOSFBConnect::GetCurrentAccessToken( lua_State *L ) const
{
	FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
	if ( accessToken )
	{
		// Table of access token data to be returned
		lua_createtable( L, 0, 7 );
		
		// Token string - like in fbconnect event
		lua_pushstring( L, [accessToken.tokenString UTF8String] );
		lua_setfield( L, -2, "token" );
		
		// Expiration date - like in fbconnect event
		lua_pushnumber( L, [accessToken.expirationDate timeIntervalSince1970] );
		lua_setfield( L, -2, "expiration" );
		
		// Refresh date
		lua_pushnumber( L, [accessToken.refreshDate timeIntervalSince1970] );
		lua_setfield( L, -2, "lastRefreshed" );
		
		// App Id
		lua_pushstring( L, [accessToken.appID UTF8String] );
		lua_setfield( L, -2, "appId" );
		
		// User Id
		lua_pushstring( L, [accessToken.userID UTF8String] );
		lua_setfield( L, -2, "userId" );
		
		// Granted permissions
		NSArray *grantedPermissions = accessToken.permissions.allObjects;
		if ( CreateLuaTableFromStringArray( L, grantedPermissions ) )
		{
			// Assign the granted permissions table to the access token table,
			// which is now 2nd from the top of the stack.
			lua_setfield( L, -2, "grantedPermissions" );
		}
		
		// Declined permissions
		NSArray *declinedPermissions = accessToken.declinedPermissions.allObjects;
		if ( CreateLuaTableFromStringArray( L, declinedPermissions ) )
		{
			// Assign the declined permissions table to the access token table,
			// which is now 2nd from the top of the stack.
			lua_setfield( L, -2, "declinedPermissions" );
		}
		
		// Now our table of access token data is at the top of the stack
	}
	else
	{
		// Return nil
		lua_pushnil( L );
	}
	return 1;
}

bool
TVOSFBConnect::IsAccessDenied() const
{
	return ! fFacebookAccountType.accessGranted;
}

void
TVOSFBConnect::Login( const char *permissions[], int numPermissions, bool attemptNativeLogin ) const
{
	// The read and publish permissions should be requested seperately
	NSMutableArray *readPermissions = nil;
	NSMutableArray *publishPermissions = nil;
	if ( numPermissions )
	{
		FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
		readPermissions = [NSMutableArray arrayWithCapacity:numPermissions];
		publishPermissions = [NSMutableArray arrayWithCapacity:numPermissions];
		for ( int i = 0; i < numPermissions; i++ )
		{
			NSString *str = [[NSString alloc] initWithUTF8String:permissions[i]];
			
			// Don't request the permission again if the accessToken already has it
			if ( ( accessToken && ! [accessToken.permissions containsObject:str] ) || ! accessToken )
			{
				// This might need to change if the sdk is upgraded
				if ( IsPublishPermission(str) )
				{
					[publishPermissions addObject:str];
				}
				else
				{
					[readPermissions addObject:str];
				}
			}

			[str release];
		}
	}
	
	if ( attemptNativeLogin )
	{
		// Request for access to a native account
		// Based on: http://stackoverflow.com/questions/20066195/apps-will-not-shown-in-setting-facebook-if-the-account-is-signed-in-after-the-a
		// Note: one should not check if the account is available until the access right is granted.
		// This is because an account is only made available if access has been granted to it.
		[fAccountStore requestAccessToAccountsWithType:fFacebookAccountType
											   options:@{ACFacebookAppIdKey: fFacebookAppId, ACFacebookPermissionsKey: @[@"read_stream"]}
											completion:^(BOOL granted, NSError *error) {
												if ( granted )
												{
													// Use the System account we have access to for login.
													[fLoginManager setLoginBehavior:FBSDKLoginBehaviorSystemAccount];
												}
												else
												{
													// Either there is no system account, and error occured, or access to it has been explicitly denied.
													// So let the Facebook SDK take care of things in its default way.
													[fLoginManager setLoginBehavior:FBSDKLoginBehaviorNative];
												}
												
												LoginAppropriately(readPermissions, publishPermissions);
											}];
	}
	else
	{
		LoginAppropriately(readPermissions, publishPermissions);
	}
}

void
TVOSFBConnect::LoginAppropriately( NSArray *readPermissions, NSArray *publishPermissions ) const
{
	if ( [readPermissions count] > 0 || [publishPermissions count] > 0 )
	{
		RequestPermissions( readPermissions, publishPermissions );
	}
	else
	{
		LoginWithOnlyRequiredPermissions();
	}
}
	
void
TVOSFBConnect::LoginWithOnlyRequiredPermissions() const
{
	[fLoginManager logInWithReadPermissions:@[@"public_profile", @"user_friends"] handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
		const char functionName[] = "TVOSFBConnect::LoginWithOnlyRequiredPermissions::logInWithReadPermissions::handler()";
		
		if (error)
		{
			LoginStateChanged( FBConnectLoginEvent::kLoginFailed, error );
		}
		else if (result.isCancelled)
		{
			LoginStateChanged( FBConnectLoginEvent::kLoginCancelled, nil );
		}
		else
		{
			FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
			if ( ! accessToken || // Should never happen if login was successful
				! [[result token] isEqualToAccessToken:accessToken] )
			{
				CORONA_LOG_ERROR( "%s%s", functionName, kLostAccessTokenError );
				return;
			}
			// Logged-in successfully!
			LoginStateChanged( FBConnectLoginEvent::kLogin, nil );
		}
	}];
}
	
void
TVOSFBConnect::RequestPermissions( NSArray *readPermissions, NSArray *publishPermissions ) const
{
	const char functionName[] = "TVOSFBConnect::RequestPermissions()";
	
	// If someone is trying to request additional permissions before doing an initial login, tack on the required read permissions.
	FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
	NSArray *fRequiredPermissions = [NSArray arrayWithObjects:@"public_profile", @"user_friends", nil];
	for ( int i = 0; i < [fRequiredPermissions count]; i++ )
	{
		// If this required permission hasn't been granted, or we haven't logged in yet.
		NSString *permissionToCheck = [fRequiredPermissions objectAtIndex:i];
		if ( ( accessToken && ! [accessToken.permissions containsObject:permissionToCheck] ) || ! accessToken )
		{
			if ( ! readPermissions ) // They need to do an initial login first, but didn't request any additional read permissions.
			{
				readPermissions = [NSArray arrayWithObject:permissionToCheck];
			}
			else
			{
				readPermissions = [readPermissions arrayByAddingObject:permissionToCheck];
			}
		}
	}
	
	
	// If you ask for multiple permissions at once, you
	// should check if specific permissions missing
	int numPermissions = (int)([readPermissions count] + [publishPermissions count]);
	if ( numPermissions > 0 )
	{
		if ( readPermissions && readPermissions.count > 0 )
		{
			// Inform the user that only one type of permission can be requested at a time. The others will be ignored.
			if ( publishPermissions && publishPermissions.count > 0 )
			{
				CORONA_LOG_WARNING( "%s%s", functionName, ": cannot process read and publish permissions at the same time. Only the read permissions will be requested." );
			}
			
			[fLoginManager logInWithReadPermissions:readPermissions handler:^( FBSDKLoginManagerLoginResult *result, NSError *error )
			 {
				 HandleRequestPermissionsResponse( readPermissions, result, error );
			 }];
		}
		else if ( publishPermissions && publishPermissions.count > 0 )
		{
			// If there aren't any read permissions and the number of requested permissions is > 0 then they have to be publish permissions
			[fLoginManager logInWithPublishPermissions:publishPermissions handler:^( FBSDKLoginManagerLoginResult *result, NSError *error )
			 {
				 HandleRequestPermissionsResponse( publishPermissions, result, error );
			 }];
		}
		else if ( ! accessToken )
		{
			// They still need to login, but were a jerk and passed in empty permission arrays.
			// So login with only required permissions.
			LoginWithOnlyRequiredPermissions();
		}
		else
		{
			// We've already been granted all the permissions we requested.
			LoginStateChanged( FBConnectLoginEvent::kLogin, nil );
		}
	}
	else if ( ! accessToken )
	{
		// They still need to login, but only with required permissions.
		LoginWithOnlyRequiredPermissions();
	}
	else
	{
		// Send a login event since there's nothing to be done here.
		LoginStateChanged( FBConnectLoginEvent::kLogin, nil );
	}
}
	
void
TVOSFBConnect::Logout() const
{
	[fLoginManager logOut];
	LoginStateChanged(FBConnectLoginEvent::kLogout, nil);
}

void
TVOSFBConnect::Request( lua_State *L, const char *path, const char *httpMethod, int index ) const
{
	const char functionName[] = "TVOSFBConnect::Request()";
	
	if ( [FBSDKAccessToken currentAccessToken] )
	{
		// Convert common params
		NSString *pathString = [NSString stringWithUTF8String:path];
		NSString *httpMethodString = [NSString stringWithUTF8String:httpMethod];
		
		// Validate HTTP Method
		if (! [httpMethodString isEqualToString:@"GET"] && ! [httpMethodString isEqualToString:@"POST"] && ! [httpMethodString isEqualToString:@"DELETE"])
		{
			CORONA_LOG_ERROR( "%s%s", functionName, ": only supports HttpMethods GET, POST, and DELETE! Cancelling request." );
			return;
		}

		NSDictionary *params = nil;
		if ( LUA_TTABLE == lua_type( L, index ) )
		{
			params = CoronaLuaCreateDictionary( L, index );
		}
		else
		{
			params = [NSDictionary dictionary];
		}

		// To debug Graph Requests, uncomment this line
		//[FBSDKSettings setLoggingBehavior:[NSSet setWithObject:FBSDKLoggingBehaviorGraphAPIDebugInfo]];
		
		[[[FBSDKGraphRequest alloc] initWithGraphPath:pathString parameters:params HTTPMethod:httpMethodString]
		 startWithCompletionHandler:^( FBSDKGraphRequestConnection *connection, id result, NSError *error )
		 {
			 const char functionName[] = "TVOSFBConnect::Request::FBSDKGraphRequestHandler()";
			 
			 if ( ! error )
			 {
				 if ( ! result ) // No error and no result would be a Facebook bug according to their docs.
				 {
					 CORONA_LOG_ERROR( "%s%s", functionName, ": could not send a response because facebook didn't give a response! On iOS, this is a bug in the Facebook SDK!" );
					 return;
				 }
				 else if ( ! [NSJSONSerialization isValidJSONObject:result] )
				 {
					 CORONA_LOG_ERROR( "%s%s", functionName, ": could not parse the response from Facebook!" );
				 }
				 
				 NSData *jsonObject = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
				 NSString *jsonString = [[NSString alloc] initWithData:jsonObject encoding:NSUTF8StringEncoding];
				 FBConnectRequestEvent e( [jsonString UTF8String], false );
				 Dispatch( e );
			 }
			 else
			 {
				 FBConnectRequestEvent e( [[error localizedDescription] UTF8String], true );
				 Dispatch( e );
			 }
		 }];
	}
	else
	{
		// Can't perform a Graph Request without being logged in.
		// TODO: Log the user in, and then retry the same Graph API request.
		CORONA_LOG_ERROR( "%s%s", functionName, ": cannot process a Graph API request without being logged in. Please call facebook.login() before calling facebook.request()." );
	}
}
	
void
TVOSFBConnect::PublishInstall() const
{
	[FBSDKAppEvents activateApp];
}

void
TVOSFBConnect::ShowDialog( lua_State *L, int index ) const
{
	const char invalidParametersErrorMessage[] = "TVOSFBConnect::ShowDialog(): Invalid parameters passed to facebook.showDialog( action [, params] ).";
	
	NSString *action = nil;
	NSDictionary *dict = nil;

	// Verify arguments
	if ( lua_isstring( L, 1 ) )
	{
		const char *str = lua_tostring( L, 1 );
		if ( LUA_TSTRING == lua_type( L, 1 ) && str )
		{
			action = [NSString stringWithUTF8String:str];
		}
		
		if ( LUA_TTABLE == lua_type( L, 2 ) )
		{
			dict = CoronaLuaCreateDictionary( L, 2 );
		}
	}
	else
	{
		CORONA_LOG_ERROR( "%s", invalidParametersErrorMessage );
	}
	
	if ( CORONA_VERIFY( action ) )
	{
		// TODO: REIMPLEMENT FACEBOOK PLACES AND FRIENDS BASED ON WHAT'S HERE!
		// Places
//		else if ( 0 == strcmp( "place", chosenOption ) )
//		{
//			// A reference to our callback handler
//			static int callbackRef = 0;
//	
//			// Set reference to onComplete function
//			if ( lua_gettop( L ) > 1 )
//			{
//				// Set the delegates callbackRef to reference the onComplete function (if it exists)
//				if ( lua_isfunction( L, lua_gettop( L ) ) )
//				{
//					callbackRef = luaL_ref( L, LUA_REGISTRYINDEX );
//				}
//			}
//	
//			static float longitude = 48.857875;
//			static float latitude = 2.294635;
//			static const char *chosenTitle;
//			static const char *searchText;
//			static int resultsLimit = 50;
//			static int radiusInMeters = 1000;
//	
//			NSString *placePickerTitle = [NSString stringWithUTF8String:"Select a Place"];
//	
//			// Get the name key
//			if ( ! lua_isnoneornil( L, -1 ) )
//			{
//				// Options table exists, retrieve latitude key
//				lua_getfield( L, -1, "longitude" );
//	
//				// If the key has been specified, is not nil and it is a number then check it.
//				if ( ! lua_isnoneornil( L, -1 ) && lua_isnumber( L, -1 ) )
//				{
//					// Enforce number
//					luaL_checktype( L, -1, LUA_TNUMBER );
//	
//					// Check the string
//					longitude = luaL_checknumber( L, -1 );
//				}
//	
//				// Options table exists, retrieve latitude key
//				lua_getfield( L, -2, "latitude" );
//	
//				// If the key has been specified, is not nil and it is a number then check it.
//				if ( ! lua_isnoneornil( L, -1 ) && lua_isnumber( L, -1 ) )
//				{
//					// Enforce number
//					luaL_checktype( L, -1, LUA_TNUMBER );
//	
//					// Check the number
//					latitude = luaL_checknumber( L, -1 );
//				}
//	
//				// Options table exists, retrieve title key
//				lua_getfield( L, -3, "title" );
//	
//				// If the key has been specified, is not nil and it is a string then check it.
//				if ( ! lua_isnoneornil( L, -1 ) && lua_isstring( L, -1 ) )
//				{
//					// Enforce string
//					luaL_checktype( L, -1, LUA_TSTRING );
//	
//					// Check the string
//					chosenTitle = luaL_checkstring( L, -1 );
//				}
//	
//				// Set the controller's title
//				if ( chosenTitle )
//				{
//					placePickerTitle = [NSString stringWithUTF8String:chosenTitle];
//				}
//	
//				// Options table exists, retrieve searchText key
//				lua_getfield( L, -4, "searchText" );
//	
//				// If the key has been specified, is not nil and it is a string then check it.
//				if ( ! lua_isnoneornil( L, -1 ) && lua_isstring( L, -1 ) )
//				{
//					// Enforce string
//					luaL_checktype( L, -1, LUA_TSTRING );
//	
//					// Check the string
//					searchText = luaL_checkstring( L, -1 );
//				}
//				else
//				{
//					searchText = "restuaruant";
//				}
//	
//				// Options table exists, retrieve resultsLimit key
//				lua_getfield( L, -5, "resultsLimit" );
//	
//				// If the key has been specified, is not nil and it is a string then check it.
//				if ( ! lua_isnoneornil( L, -1 ) && lua_isnumber( L, -1 ) )
//				{
//					// Enforce number
//					luaL_checktype( L, -1, LUA_TNUMBER );
//	
//					// Check the number
//					resultsLimit = luaL_checknumber( L, -1 );
//				}
//	
//				// Options table exists, retrieve radiusInMeters key
//				lua_getfield( L, -6, "radiusInMeters" );
//	
//				// If the key has been specified, is not nil and it is a string then check it.
//				if ( ! lua_isnoneornil( L, -1 ) && lua_isnumber( L, -1 ) )
//				{
//					// Enforce number
//					luaL_checktype( L, -1, LUA_TNUMBER );
//	
//					// Check the number
//					radiusInMeters = luaL_checknumber( L, -1 );
//				}
//			}
//	
//			// Set the controller's title
//			if ( chosenTitle )
//			{
//				placePickerTitle = [NSString stringWithUTF8String:chosenTitle];
//			}
//	
//			// Create the place picker view controller
//			FBPlacePickerViewController *placePicker = [[FBPlacePickerViewController alloc] init];
//			placePicker.title = placePickerTitle;
//			placePicker.searchText = [NSString stringWithUTF8String:searchText];
//	
//			// Set the coordinates
//			CLLocationCoordinate2D coordinates =
//				CLLocationCoordinate2DMake( longitude, latitude );
//	
//			// Setup the cache descriptor
//			FBCacheDescriptor *placeCacheDescriptor =
//				[FBPlacePickerViewController
//				 cacheDescriptorWithLocationCoordinate:coordinates
//				 radiusInMeters:radiusInMeters
//				 searchText:placePicker.searchText
//				 resultsLimit:resultsLimit
//				 fieldsForRequest:nil];
//	
//			// Configure the cache descriptor
//			[placePicker configureUsingCachedDescriptor:placeCacheDescriptor];
//			// Load the data
//			[placePicker loadData];
//	
//			// Show the view controller
//			[placePicker presentModallyFromViewController:fRuntime.appViewController
//													animated:YES
//													handler:^(FBViewController *sender, BOOL donePressed)
//													{
//														if (donePressed)
//														{
//															//NSLog( @"%@", placePicker.selection );
//	
//															/*
//																		List of keys returned
//	
//																		"category" - string
//																		"id" - number
//																		"location" - table ie.
//																		location =
//																		{
//																			"city" - string,
//																			"country" - string.
//																			"latitude" - string.
//																			"longitude" - string.
//																			"state" - string.
//																			"street" - string.
//																			"zip" - string.
//																		}
//	
//																		"name" - string.
//	
//																		"picture" - table. .ie
//																		picture =
//																		{
//																			data =
//																			{
//																				"is_silhouette" - bool
//																				"url" - string
//																			}
//																		}
//	
//																		"were_here_count" - number
//	
//	
//																		*/
//	
//															// If there is a callback to exectute
//															if ( 0 != callbackRef )
//															{
//																// Push the onComplete function onto the stack
//																lua_rawgeti( L, LUA_REGISTRYINDEX, callbackRef );
//	
//																// event table
//																lua_newtable( L );
//	
//																// event.data table
//																lua_newtable( L );
//	
//																// Get the properties from the graph
//	
//																const char *placeCategory = [(NSString*) [placePicker.selection objectForKey:@"category"] UTF8String];
//																lua_pushstring( L, placeCategory );
//																lua_setfield( L, -2, "category" );
//	
//																const char *placeId = [(NSString*) [placePicker.selection objectForKey:@"id"] UTF8String];
//																lua_pushstring( L, placeId );
//																lua_setfield( L, -2, "id" );
//	
//																const char *placeName = [(NSString*) [placePicker.selection objectForKey:@"name"] UTF8String];
//																lua_pushstring( L, placeName );
//																lua_setfield( L, -2, "name" );
//	
//																static int placeWereHere = [(NSString*) [placePicker.selection objectForKey:@"were_here_count"] intValue];
//																lua_pushnumber( L, placeWereHere );
//																lua_setfield( L, -2, "wereHere" );
//	
//																const char *placeCity = [(NSString*) [[placePicker.selection objectForKey:@"location"] valueForKey:@"city"] UTF8String];
//																lua_pushstring( L, placeCity );
//																lua_setfield( L, -2, "city" );
//	
//																const char *placeCountry = [(NSString*) [[placePicker.selection objectForKey:@"location"] valueForKey:@"country"] UTF8String];
//																lua_pushstring( L, placeCountry );
//																lua_setfield( L, -2, "country" );
//	
//																NSDecimalNumber *thelatitude = [[placePicker.selection objectForKey:@"location"] valueForKey:@"latitude"];
//																static float placeLatitude = [(NSDecimalNumber*)thelatitude floatValue];
//																lua_pushnumber( L, placeLatitude );
//																lua_setfield( L, -2, "latitude" );
//	
//																NSDecimalNumber *thelongitude = [[placePicker.selection objectForKey:@"location"] valueForKey:@"longitude"];
//																static float placeLongitude = [(NSDecimalNumber*)thelongitude floatValue];
//																lua_pushnumber( L, placeLongitude );
//																lua_setfield( L, -2, "longitude" );
//	
//																const char *placeState = [(NSString*) [[placePicker.selection objectForKey:@"location"] valueForKey:@"state"] UTF8String];
//																lua_pushstring( L, placeState );
//																lua_setfield( L, -2, "state" );
//	
//																const char *placeStreet = [(NSString*) [[placePicker.selection objectForKey:@"location"] valueForKey:@"street"] UTF8String];
//																lua_pushstring( L, placeStreet );
//																lua_setfield( L, -2, "street" );
//	
//																const char *placeZip = [(NSString*) [[placePicker.selection objectForKey:@"location"] valueForKey:@"zip"] UTF8String];
//																lua_pushstring( L, placeZip );
//																lua_setfield( L, -2, "zip" );
//	
//																// Create picture table
//																lua_newtable( L );
//																// Create picture.data table
//																lua_newtable( L );
//	
//																// Set the place picture.data 'is_silhouette' property
//																bool placeIsSillhouette = (bool)[[[placePicker.selection objectForKey:@"picture"] valueForKey:@"data"] valueForKey:@"is_silhouette"];
//																lua_pushboolean( L, placeIsSillhouette );
//																lua_setfield( L, -2, "isSilhouette" );
//	
//																// Set the place picture.data 'url' property
//																const char *placeUrl = [[[[placePicker.selection objectForKey:@"picture"] valueForKey:@"data"] valueForKey:@"url"] UTF8String];
//																lua_pushstring( L, placeUrl );
//																lua_setfield( L, -2, "url" );
//	
//																// Set the data nested table
//																lua_setfield(L, -2, "data" );
//																// Set the picture outer table
//																lua_setfield( L, -2, "picture" );
//	
//																// Set event.data
//																lua_setfield( L, -2, "data" );
//	
//																// Set event.name property
//																lua_pushstring( L, "fbDialog" ); // Value ( name )
//																lua_setfield( L, -2, "name" ); // Key
//	
//																// Set event.type property
//																lua_pushstring( L, "place" ); // Value ( name )
//																lua_setfield( L, -2, "type" ); // Key
//	
//																// Call the onComplete function
//																Corona::Lua::DoCall( L, 1, 1 );
//	
//																// Free the refrence
//																lua_unref( L, callbackRef );
//															}
//														}
//													}];
//	
//		}
//		// Friends
//		else if ( 0 == strcmp( "friends", chosenOption ) )
//		{
//			// A reference to our callback handler
//			static int callbackRef = 0;
//	
//			// Set reference to onComplete function
//			if ( lua_gettop( L ) > 1 )
//			{
//				// Set the delegates callbackRef to reference the onComplete function (if it exists)
//				if ( lua_isfunction( L, lua_gettop( L ) ) )
//				{
//					callbackRef = luaL_ref( L, LUA_REGISTRYINDEX );
//				}
//			}
//	
//			FBFriendPickerViewController *friendPicker = [[FBFriendPickerViewController alloc] init];
//	
//			// Set up the friend picker to sort and display names the same way as the
//			// iOS Address Book does.
//	
//			friendPicker.sortOrdering = FBFriendSortByLastName;
//			friendPicker.displayOrdering = FBFriendDisplayByFirstName;
//	
//			// Load the data
//			[friendPicker loadData];
//	
//			// Show the view controller
//			[friendPicker presentModallyFromViewController:fRuntime.appViewController
//													  animated:YES
//													   handler:^( FBViewController *sender, BOOL donePressed )
//													   {
//															if ( donePressed )
//															{
//																//NSDictionary *value = [friendPicker.selection objectAtIndex:1];
//																//NSLog( @"%@", [value objectForKey:@"name"] );
//																/*
//																		List of keys returned
//	
//																		"first_name" - string
//																		"last_name" - string
//																		"name" - string (full name)
//																		"id" - number
//																		"picture" - table containing subtable ie
//																		picture =
//																		{
//																			data =
//																			{
//																				"is_silhouette" - number 0 false, 1 true
//																				"url" - url to friend picture
//																			}
//																		}
//																		*/
//	
//																		//NSLog( @"value of data silhouette is %@", [[[items valueForKey:@"picture"] valueForKey:@"data"] valueForKey:@"is_silhouette"] );
//	
//																// If there is a callback to exectute
//																if ( 0 != callbackRef )
//																{
//																	// Push the onComplete function onto the stack
//																	lua_rawgeti( L, LUA_REGISTRYINDEX, callbackRef );
//	
//																	// Event table
//																	lua_newtable( L );
//	
//																	// event.data table
//																	lua_newtable( L );
//	
//																	// Total number of items (friends) in the dictionary
//																	int numOfItems = [friendPicker.selection count];
//	
//																	// Loop through the dictionary and pass the data back to lua
//																	for ( int i = 0; i < numOfItems; i ++ )
//																	{
//																		// Create a table to hold the current friend data
//																		lua_newtable( L );
//	
//																		// Get the properties from the current dictionary index
//																		NSDictionary *items = [friendPicker.selection objectAtIndex:i];
//	
//																		// Set the friend's first name
//																		const char *friendFirstName = [[items objectForKey:@"first_name"] UTF8String];
//																		lua_pushstring( L, friendFirstName );
//																		lua_setfield( L, -2, "firstName" );
//	
//																		// Set the friend's last name
//																		const char *friendLastName = [[items objectForKey:@"last_name"] UTF8String];
//																		lua_pushstring( L, friendLastName );
//																		lua_setfield( L, -2, "lastName" );
//	
//																		// Set the friend's full name
//																		const char *friendFullName = [[items objectForKey:@"name"] UTF8String];
//																		lua_pushstring( L, friendFullName );
//																		lua_setfield( L, -2, "fullName" );
//	
//																		// Set the friend's id
//																		const char *friendId = [[items objectForKey:@"id"] UTF8String];
//																		lua_pushstring( L, friendId );
//																		lua_setfield( L, -2, "id" );
//	
//																		// Create picture table
//																		lua_newtable( L );
//																		// Create picture.data table
//																		lua_newtable( L );
//	
//																		// Set the friends picture.data 'is_silhouette' property
//																		id isSillhouette = [[[items valueForKey:@"picture"] valueForKey:@"data"] valueForKey:@"is_silhouette"];
//																		BOOL friendIsSillhouette = [(NSNumber*)isSillhouette boolValue];
//																		lua_pushboolean( L, friendIsSillhouette );
//																		lua_setfield( L, -2, "isSilhouette" );
//	
//																		// Set the friends picture.data 'url' property
//																		const char *friendUrl = [[[[items valueForKey:@"picture"] valueForKey:@"data"] valueForKey:@"url"] UTF8String];
//																		lua_pushstring( L, friendUrl );
//																		lua_setfield( L, -2, "url" );
//	
//																		// Set the data nested table
//																		lua_setfield(L, -2, "data" );
//																		// Set the picture outer table
//																		lua_setfield( L, -2, "picture" );
//	
//																		// Set the main table
//																		lua_rawseti( L, -2, i + 1 );
//																	}
//	
//																	// Set event.data
//																	lua_setfield( L, -2, "data" );
//	
//																	// Set event.name property
//																	lua_pushstring( L, "fbDialog" ); // Value ( name )
//																	lua_setfield( L, -2, "name" ); // Key
//	
//																	// Set event.type property
//																	lua_pushstring( L, "friends" ); // Value ( name )
//																	lua_setfield( L, -2, "type" ); // Key
//	
//																	// Call the onComplete function
//																	Corona::Lua::DoCall( L, 1, 1 );
//	
//																	// Free the refrence
//																	lua_unref( L, callbackRef );
//																}
//															}
//													   }];
//		}
		// Standard facebook.showDialog
//		else
//		{
			if ( IsShareAction( action ) )
			{
				// Grab all the base share parameters
				NSURL *contentUrl = nil;
				NSArray *peopleIds = nil;
				NSString *placeId = nil;
				NSString *ref = nil;
				
				if ( dict )
				{
					contentUrl = [NSURL URLWithString:[dict objectForKey:@"link"]];
					
					// We use lower case "d" in "Id" for consistency with Android.
					peopleIds = [[dict objectForKey:@"peopleIds"] allValues];
					placeId = [dict objectForKey:@"placeId"];
					
					ref = [dict objectForKey:@"ref"];
					
				}
				
				// Present the Share dialog for the desired content
				if ( [action isEqualToString:@"feed"] || [action isEqualToString:@"link"] )
				{
					// Grab the link-specific share content
					NSString *contentDescription = nil;
					NSString *contentTitle = nil;
					NSURL *imageURL = nil;
					
					if ( dict )
					{
						contentDescription = [dict objectForKey:@"description"];
						contentTitle = [dict objectForKey:@"title"];
						imageURL = [NSURL URLWithString:[dict objectForKey:@"picture"]];
					}
					
					FBSDKShareLinkContent *content = [[[FBSDKShareLinkContent alloc] init] autorelease];
					content.contentDescription = contentDescription;
					content.contentTitle = contentTitle;
					content.contentURL = contentUrl;
					content.imageURL = imageURL;
					content.peopleIDs = peopleIds;
					content.placeID = placeId;
					content.ref = ref;
					
					if ( [action isEqualToString:@"feed"] )
					{
						// Present the traditional feed dialog
						FBSDKShareDialog *dialog = [[[FBSDKShareDialog alloc] init] autorelease];
						dialog.fromViewController = fRuntime.appViewController;
						// NOTE: This is currently undocumented in Facebook SDK v4.4.0 docs.
						// Find it in FBSDKShareDialog.m: Properties
						dialog.shareContent = content;
						dialog.delegate = fShareDialogDelegate;
						dialog.mode = FBSDKShareDialogModeFeedWeb;
						[dialog show];
					}
					else // We're using the new sharing model.
					{
						// Presenting the share dialog behaves differently depending on whether the user has the Facebook app installed on their device or not.
						// With the Facebook app, things like tagging friends and a location are built-in. Otherwise, these things aren't built-in.
						[FBSDKShareDialog showFromViewController:fRuntime.appViewController
													 withContent:content
														delegate:fShareDialogDelegate];
					}
				}
			}
			else if ( [action isEqualToString:@"requests"] || [action isEqualToString:@"apprequests"] )
			{
				// Grab game request-specific data
				NSString *message = nil;
				NSString *to = nil; // Is mapped to "recipients" as Facebook deprecated "to" on iOS.
				NSString *data = nil;
				NSString *title = nil;
				FBSDKGameRequestActionType actionType = nil;
				NSString *objectId = nil;
				FBSDKGameRequestFilter filters = nil;
				NSArray *suggestions = nil; // Is mapped to "recipientSuggestions" as Facebook deprecated "suggestions" on iOS.
				
				if ( dict )
				{
					// Parse simple options
					message = [dict objectForKey:@"message"];
					to = [dict objectForKey:@"to"];
					data = [dict objectForKey:@"data"];
					title = [dict objectForKey:@"title"];
					objectId = [dict objectForKey:@"objectId"];
					
					// Parse complex options
					// ActionType
					id actionTypeFromLuaTable = [dict objectForKey:@"actionType"];
					if ( [actionTypeFromLuaTable isKindOfClass:[NSString class]] )
					{
						actionType = GetActionTypeFrom(actionTypeFromLuaTable);
					}
					else if ( actionTypeFromLuaTable )
					{
						CORONA_LOG_ERROR( "%s%s", invalidParametersErrorMessage, " options.actionType must be a string!" );
						return;
					}
					
					// Filters
					id filterFromLuaTable = [dict objectForKey:@"filter"];
					if ( [filterFromLuaTable isKindOfClass:[NSString class]] )
					{
						filters = GetFilterFrom(filterFromLuaTable);
					}
					else if ( filterFromLuaTable )
					{
						CORONA_LOG_ERROR( "%s%s", invalidParametersErrorMessage, " options.filter must be a string!" );
						return;
					}
					
					// Suggestions
					suggestions = [[dict objectForKey:@"suggestions"] allValues];
					if ( suggestions )
					{
						// Purge for malformed data in the "suggestions" table. Throw an error to the developer if we find any.
						// Based on: http://stackoverflow.com/questions/6091414/finding-out-whether-a-string-is-numeric-or-not
						NSCharacterSet* notDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
						for ( int i = 0; i < [suggestions count]; i++ )
						{
							// If this object isn't a string containing only numbers, then it's malformed data!
							id suggestion = [suggestions objectAtIndex:i];
							if ( ![suggestion isKindOfClass:[NSString class]]
								|| [(NSString*)suggestion rangeOfCharacterFromSet:notDigits].location != NSNotFound)
							{
								CORONA_LOG_ERROR( "%s%s", invalidParametersErrorMessage, " options.suggestions must contain Facebook User IDs as strings!" );
								return;
							}
						}
					}
				}
				
				// Create a game request dialog
				// ONLY WORKS IF YOUR APP IS CATEGORIZED AS A GAME IN FACEBOOK DEV PORTAL
				FBSDKGameRequestContent *content = [[[FBSDKGameRequestContent alloc] init] autorelease];
				content.message = message;
				content.data = data;
				content.title = title;
				content.actionType = actionType;
				content.objectID = objectId;
				content.filters = filters;
				content.recipientSuggestions = suggestions;
				
				// Since Android can only pre-load one person at a time, we need to match
				// this on iOS, despite having the ability to pre-load multiple people.
				// We nil check the "to" parameters since Objective-C won't allow nils in
				// arrays, and is silent about it if you try.
				content.recipients = to ? [NSArray arrayWithObject:to] : nil;
				
				[FBSDKGameRequestDialog showWithContent:content delegate:fGameRequestDialogDelegate];
			}
			else
			{
				CORONA_LOG_ERROR( "%s", invalidParametersErrorMessage );
			}
//		}
	}
	else //! CORONA_VERIFY( action )
	{
		CORONA_LOG_ERROR( "%s", invalidParametersErrorMessage );
	}
}

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

