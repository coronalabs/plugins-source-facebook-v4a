// ----------------------------------------------------------------------------
// 
// IOSFBConnect.cpp
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// Reviewers:
// 		Walter
//
// ----------------------------------------------------------------------------

#include "IOSFBConnect.h"

#include "CoronaAssert.h"
#include "CoronaLua.h"
#include "CoronaVersion.h"

#import "CoronaLuaIOS.h"
#import "CoronaRuntime.h"

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <FBSDKShareKit/FBSDKShareKit.h>

#import <Accounts/ACAccountStore.h>
#import <Accounts/ACAccountType.h>

#import "CoronaDelegate.h"

// IOSFBConnectDelegate
// ----------------------------------------------------------------------------
@interface IOSFBConnectDelegate : NSObject< CoronaDelegate >
{
	NSString* urlPrefix;
	Corona::IOSFBConnect *fOwner;
}

- (id)initWithOwner:(Corona::IOSFBConnect*)owner;

@end


@implementation IOSFBConnectDelegate

- (id)initWithOwner:(Corona::IOSFBConnect*)owner
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
@interface FBShareDelegate : IOSFBConnectDelegate < FBSDKSharingDelegate >
@end


@implementation FBShareDelegate

// FBSDKSharingDelegate
// ----------------------------------------------------------------------------
- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary *)results
{
	// TODO: Handle conflicts of having the Done button in a SafariViewController land here when it should be a cancel and not getting results back.
	// Need this to give a string in the following form to match Android:
	// fbconnect://success?PostID=10205888988338155_10206449924601211
	NSString *postId = [results objectForKey:@"postId"];
	const char* urlResponse = [[NSString stringWithFormat:@"%@%@%@", urlPrefix, @"PostID=", postId] UTF8String];
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

// FBGameRequestDelegate
// ----------------------------------------------------------------------------
@interface FBGameRequestDelegate : IOSFBConnectDelegate < FBSDKGameRequestDialogDelegate >
@end


@implementation FBGameRequestDelegate

// FBSDKGameRequestDialogDelegate
// ----------------------------------------------------------------------------
- (void)gameRequestDialog:(FBSDKGameRequestDialog *)gameRequestDialog didCompleteWithResults:(NSDictionary *)results
{
	// Need this to give a string in the following form to match Android:
	// fbconnect://success?RequestID=1074342222584935&Recipient=126305257702577
	NSString *urlResponseString = [NSString stringWithFormat:@"%@%@%@", urlPrefix, @"RequestID=", [results objectForKey:@"request"]];
	
	// Get all recipients of the Game Request.
	for (id recipient in results)
	{
		// Don't add the requestId again.
		if ( [recipient isEqualToString:@"request"] ) continue;
		
		// Append this recipient, trimming out any newlines or whitespace we may have gotten from Facebook.
		NSString *recipientValue = (NSString *)[results objectForKey:recipient];
		
		// TODO: Trim out any whitespace or newline characters from Facebook response.
		
		urlResponseString = [NSString stringWithFormat:@"%@%@%@", urlResponseString, @"&Recipient=", recipientValue];
	}
	
	const char* urlResponse = [urlResponseString UTF8String];
	
	Corona::FBConnectDialogEvent e( urlResponse, false, true );
	fOwner->Dispatch( e );
}

- (void)gameRequestDialog:(FBSDKGameRequestDialog *)gameRequestDialog didFailWithError:(NSError *)error
{
	Corona::FBConnectDialogEvent e( [[error localizedDescription] UTF8String], true, false );
	fOwner->Dispatch( e );
}

- (void)gameRequestDialogDidCancel:(FBSDKGameRequestDialog *)gameRequestDialog
{
	Corona::FBConnectDialogEvent e( "Dialog was cancelled by user", false, false );
	fOwner->Dispatch( e );
}

@end

// FBNoAppIdAlertDelegate
// ----------------------------------------------------------------------------
@interface FBNoAppIdAlertDelegate : NSObject< UIAlertViewDelegate >

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;

@end

@implementation FBNoAppIdAlertDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	switch( buttonIndex )
	{
		case 0: // Cancel button
			break;
		case 1: // Get App ID button
			[[UIApplication sharedApplication] openURL:[[NSURL alloc] initWithString:@"https://developers.facebook.com/"]];
			break;
		case 2: // Integrate in Corona button
			[[UIApplication sharedApplication] openURL:[[NSURL alloc] initWithString:@"https://docs.coronalabs.com/guide/social/implementFacebook/index.html#facebook"]];
			break;
		default:
			break;
	}
	
	// Exit the app so the developer can take care of the Facebook App ID.
	exit(0);
}

@end
// ----------------------------------------------------------------------------

#ifdef DEBUG_FACEBOOK_ENDPOINT

@interface IOSFBConnectConnectionDelegate : NSObject
{
	NSMutableData *fData;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError*)error;

@end

@implementation IOSFBConnectConnectionDelegate

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
	
	return new IOSFBConnect( runtime );
}

void
FBConnect::Delete( FBConnect *instance )
{
	delete instance;
}

// ----------------------------------------------------------------------------

const char IOSFBConnect::kLostAccessTokenError[] = ": lost the access token. This could be the result of another thread completing facebook.logout() before this callback was invoked.";
	
// Set up Enum - NSString conversion dictionaries.
// From: http://stackoverflow.com/questions/13171907/best-way-to-enum-nsstring
NSDictionary* IOSFBConnect::FBSDKGameRequestActionTypeDictionary =
  @{
	@"none" : @(FBSDKGameRequestActionTypeNone),
	@"send" : @(FBSDKGameRequestActionTypeSend),
	@"askfor": @(FBSDKGameRequestActionTypeAskFor),
	@"turn": @(FBSDKGameRequestActionTypeTurn)
   };
	
NSDictionary* IOSFBConnect::FBSDKGameRequestFilterDictionary =
  @{
	@"none" : @(FBSDKGameRequestFilterNone),
	@"app_users" : @(FBSDKGameRequestFilterAppUsers),
	@"app_non_users": @(FBSDKGameRequestFilterAppNonUsers)
   };
	
	
IOSFBConnect::IOSFBConnect( id< CoronaRuntime > runtime )
:	Super(),
	fRuntime( runtime ),
	fHasObserver( false ),
	fNoAppIdAlertDelegate( [[FBNoAppIdAlertDelegate alloc] init] ),
	fShareDialogDelegate( [[FBShareDelegate alloc] initWithOwner:this] ),
	fGameRequestDialogDelegate( [[FBGameRequestDelegate alloc] initWithOwner:this] ),
	fLoginManager( [[FBSDKLoginManager alloc] init] ),
#ifdef DEBUG_FACEBOOK_ENDPOINT
	fConnectionDelegate( [[IOSFBConnectConnectionDelegate alloc] init] )
#else
	fConnectionDelegate( nil )
#endif
{
	// Grab the Facebook App ID from Info.plist
	// From: http://stackoverflow.com/questions/4059101/read-version-from-info-plist
	NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
	fFacebookAppId = [infoDict objectForKey:@"FacebookAppID"];
	// Throw an alert if there's no FacebookAppID. They screwed up the plist.
	if ( ! fFacebookAppId )
	{
		UIAlertView *noAppIdAlert = [[UIAlertView alloc] initWithTitle:@"ERROR: Need Facebook App ID"
														   message:@"To develop for Facebook Connect, you need to get a Facebook App ID and integrate it into your Corona project."
														  delegate:fNoAppIdAlertDelegate
												 cancelButtonTitle:@"Cancel"
												 otherButtonTitles:@"Get App ID", @"Integrate in Corona", nil];
		[noAppIdAlert show];
	}
}

IOSFBConnect::~IOSFBConnect()
{
	[fLoginManager release];
	[fNoAppIdAlertDelegate release];
	[fShareDialogDelegate release];
	[fGameRequestDialogDelegate release];
	[fConnectionDelegate release];
}

bool
IOSFBConnect::Initialize( NSString *appId )
{
	const char functionName[] = "IOSFBConnect::Initialize()";
	
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
IOSFBConnect::LoginStateChanged( FBConnectLoginEvent::Phase state, NSError *error ) const
{
	const char functionName[] = "IOSFBConnect::LoginStateChanged()";
	
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
IOSFBConnect::ReauthorizationCompleted( NSError *error ) const
{
	LoginStateChanged( ( error ? FBConnectLoginEvent::kLoginFailed : FBConnectLoginEvent::kLogin ), error );
}

void
IOSFBConnect::Dispatch( const FBConnectEvent& e ) const
{
	e.Dispatch( fRuntime.L, GetListener() );
}

// Creates a Lua table out of an NSArray with NSStrings inside.
// Leaves the Lua table on top of the stack.
int
IOSFBConnect::CreateLuaTableFromStringArray( lua_State *L, NSArray *array )
{
	const char functionName[] = "IOSFBConnect::CreateLuaTableFromStringArray()";
	
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

void
IOSFBConnect::HandleRequestPermissionsResponse( FBSDKLoginManagerLoginResult *result, NSError *error ) const
{
	const char functionName[] = "IOSFBConnect::HandleRequestPermissionsResponse()";
	
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
		
		ReauthorizationCompleted(error);
	}
}

bool
IOSFBConnect::IsShareAction( NSString *action )
{
	return	[action isEqualToString:@"feed"] ||
			[action isEqualToString:@"link"] ||
			[action isEqualToString:@"photo"] ||
			[action isEqualToString:@"video"] ||
			[action isEqualToString:@"openGraph"];
}

FBSDKShareDialog*
IOSFBConnect::newShareDialogWithCoronaConfiguration() const
{
	// Create the share dialog and do universal configuration for it
	FBSDKShareDialog *dialog = [[[FBSDKShareDialog alloc] initWithViewController:nil content:nil delegate:fShareDialogDelegate] autorelease];
	
	// Presenting the share dialog behaves differently depending on whether the user has the Facebook app installed on their device or not.
	// With the Facebook app, things like tagging friends and a location are built-in. Otherwise, these things aren't built-in.
	if ([[[UIDevice currentDevice] systemVersion] compare:@"9.0" options:NSNumericSearch] != NSOrderedAscending)
	{
		// On iOS 9 and above, we prefer the Browser mode to match with Login using SafariView by default.
		dialog.mode = FBSDKShareDialogModeBrowser;
	}
	else // On iOS 8 or lower.
	{
		dialog.mode = FBSDKShareDialogModeAutomatic;
	}
	
	return dialog;
}
	
void
IOSFBConnect::showSharePhotoDialogWithProperties( NSMutableArray* sharePhotosArray, NSURL *contentUrl,
												 NSArray *peopleIds, NSString *placeId, NSString *ref ) const
{
	// Create the Share Dialog we'll present.
	FBSDKShareDialog *dialog = newShareDialogWithCoronaConfiguration();
	
	// Create the SharePhotoContent from the provided SharePhotoArray.
	FBSDKSharePhotoContent *content = [[[FBSDKSharePhotoContent alloc] init] autorelease];
	content.photos = sharePhotosArray;
	
	// Attach universal ShareContent fields.
	content.contentURL = contentUrl;
	content.peopleIDs = peopleIds;
	content.placeID = placeId;
	content.ref = ref;
	
	// Hook up the content to present on this Share Dialog.
	// NOTE: This is currently undocumented in Facebook SDK v4 docs.
	// Find it in FBSDKShareDialog.m: Properties
	dialog.shareContent = content;
	
	// Present the share dialog after it has been configured with Share Content.
	[dialog show];
}
	
FBSDKGameRequestActionType
IOSFBConnect::GetActionTypeFrom( NSString* actionTypeString )
{
	id actionType = [FBSDKGameRequestActionTypeDictionary objectForKey:[actionTypeString lowercaseString]];
	if ( actionType )
	{
		// Grab the value from the action type object, copy and return it.
		return (FBSDKGameRequestActionType)[(NSNumber*)actionType intValue];
	}
	return FBSDKGameRequestActionTypeNone;
}

FBSDKGameRequestFilter
IOSFBConnect::GetFilterFrom( NSString* filterString )
{
	id filter = [FBSDKGameRequestFilterDictionary objectForKey:[filterString lowercaseString]];
	if ( filter )
	{
		// Grab the value from the filter object, copy and return it.
		return (FBSDKGameRequestFilter)[(NSNumber*)filter intValue];
	}
	return FBSDKGameRequestFilterNone;
}
	
// Grabs the current access token from Facebook and converts it to a Lua table
int
IOSFBConnect::GetCurrentAccessToken( lua_State *L ) const
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
IOSFBConnect::IsAccessDenied() const
{
	return false;
}

// Note: The App-Info.plist must contain the LSApplicationQueryScheme, "fb" for this API to work.
bool
IOSFBConnect::IsFacebookAppEnabled() const
{
	return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"fb://"]];
}
	
void
IOSFBConnect::Login( const char *permissions[], int numPermissions, bool limitedLogin ) const
{
	// The read and publish permissions should be requested seperately
    
	NSMutableSet *permissionSet = [[[NSMutableSet alloc] initWithObjects:@"public_profile", nil] autorelease];
	if ( numPermissions )
	{
		FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
		for ( int i = 0; i < numPermissions; i++ )
		{
			NSString *str = [[NSString alloc] initWithUTF8String:permissions[i]];
			
			// Don't request the permission again if the accessToken already has it
			if ( ( accessToken && ! [accessToken.permissions containsObject:str] ) || ! accessToken )
			{
				[permissionSet addObject:str];
			}

			[str release];
		}
	}
	LoginAppropriately(permissionSet.allObjects, limitedLogin);
}

void
IOSFBConnect::LoginAppropriately( NSArray *permissions, bool limitedLogin ) const
{
	if ( [permissions count] > 0 )
	{
		RequestPermissions( permissions, limitedLogin );
	}
	else
	{
		LoginWithOnlyRequiredPermissions(limitedLogin);
	}
}
	
void
IOSFBConnect::LoginWithOnlyRequiredPermissions(bool limitedLogin) const
{
	if([[[FBSDKAccessToken currentAccessToken] permissions] containsObject:@"public_profile"]) {
		LoginStateChanged( FBConnectLoginEvent::kLogin, nil );
		return;
	}
    //Setup FB Configuration
    
    FBSDKLoginConfiguration *configuration = [[FBSDKLoginConfiguration alloc] initWithPermissions:@[@"public_profile"] tracking:(limitedLogin ? FBSDKLoginTrackingLimited : FBSDKLoginTrackingEnabled) nonce:@"solar2D"];
    
 	[fLoginManager logInFromViewController:nil
                             configuration:configuration
                                completion:^(FBSDKLoginManagerLoginResult * _Nullable result, NSError * _Nullable error) {
		const char functionName[] = "IOSFBConnect::LoginWithOnlyRequiredPermissions::logInWithReadPermissions::handler()";
		
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
IOSFBConnect::RequestPermissions( NSArray *permission, bool limitedLogin ) const
{
	// If someone is trying to request additional permissions before doing an initial login, tack on the required read permissions.
	FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
	NSArray *fRequiredPermissions = [NSArray arrayWithObjects:@"public_profile", /*@"user_friends", */nil];
	for ( int i = 0; i < [fRequiredPermissions count]; i++ )
	{
		// If this required permission hasn't been granted, or we haven't logged in yet.
		NSString *permissionToCheck = [fRequiredPermissions objectAtIndex:i];
		if ( ( accessToken && ! [accessToken.permissions containsObject:permissionToCheck] ) || ! accessToken )
		{
			if ( ! permission ) // They need to do an initial login first, but didn't request any additional read permissions.
			{
				permission = [NSArray arrayWithObject:permissionToCheck];
			}
			else
			{
				permission = [permission arrayByAddingObject:permissionToCheck];
			}
		}
	}
	
	if ( permission && permission.count > 0 )
	{
        //Setup FB Configuration
        
        FBSDKLoginConfiguration *configuration = [[FBSDKLoginConfiguration alloc] initWithPermissions:permission tracking:(limitedLogin ? FBSDKLoginTrackingLimited : FBSDKLoginTrackingEnabled) nonce:@"solar2D"];
		 [fLoginManager logInFromViewController:fRuntime.appViewController
                                  configuration:configuration
                                     completion:^( FBSDKLoginManagerLoginResult *result, NSError *error )
		 {
			 HandleRequestPermissionsResponse( result, error );
		 }];
	}
	else if ( ! accessToken )
	{
		// They still need to login, but were a jerk and passed in empty permission arrays.
		// So login with only required permissions.
		LoginWithOnlyRequiredPermissions(limitedLogin);
	}
	else
	{
		// We've already been granted all the permissions we requested.
		LoginStateChanged( FBConnectLoginEvent::kLogin, nil );
	}
}
	
void
IOSFBConnect::Logout() const
{
	[fLoginManager logOut];
	LoginStateChanged(FBConnectLoginEvent::kLogout, nil);
}

void
IOSFBConnect::Request( lua_State *L, const char *path, const char *httpMethod, int index ) const
{
	const char functionName[] = "IOSFBConnect::Request()";
	
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
         startWithCompletion:^(id<FBSDKGraphRequestConnecting>  _Nullable connection, id  _Nullable result, NSError * _Nullable error)
		 {
			 const char functionName[] = "IOSFBConnect::Request::FBSDKGraphRequestHandler()";
			 
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
IOSFBConnect::PublishInstall() const
{
	[FBSDKAppEvents.shared activateApp];
}

int
IOSFBConnect::GetSDKVersion( lua_State *L ) const
{
	lua_pushstring( L, [FBSDK_VERSION_STRING UTF8String] );
	return 1;
}

	
void
IOSFBConnect::DispatchInit( lua_State *L ) const
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if (GetListener() != NULL)
		{
			// Dispatch the "fbinit" event now as there's no async initialization on this platform
			CoronaLuaNewEvent( L, "fbinit" );
			
			lua_pushstring( L, "initialized" );
			lua_setfield( L, -2, "phase" );
			
			CoronaLuaDispatchEvent( L, GetListener(), 0 );
		}
	});
}
	
void
IOSFBConnect::ShowDialog( lua_State *L, int index ) const
{
	const char invalidParametersErrorMessage[] = "IOSFBConnect::ShowDialog(): Invalid parameters passed to facebook.showDialog( action [, params] ).";
	
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
		// Standard facebook.showDialog
		if ( IsShareAction( action ) )
		{
			// Grab all the base share parameters
			NSURL *contentUrl = nil;
			NSArray *peopleIds = nil;
			NSString *placeId = nil;
			NSString *ref = nil;
			
			if ( dict )
			{
				// Grab the universal parameters from Lua.
				contentUrl = [NSURL URLWithString:[dict objectForKey:@"link"]];
				
				// We use lower case "d" in "Id" for consistency with Android.
				peopleIds = [[dict objectForKey:@"peopleIds"] allValues];
				placeId = [dict objectForKey:@"placeId"];
				ref = [dict objectForKey:@"ref"];
				
			}
			
			// Present the Share dialog for the desired content
			if ( [action isEqualToString:@"feed"] || [action isEqualToString:@"link"] )
			{
				// Create the share dialog and do universal configuration for it
				FBSDKShareDialog *dialog = newShareDialogWithCoronaConfiguration();
				
				// Enforce the link parameter being required here.
				if ( !contentUrl )
				{
					CORONA_LOG_ERROR( "%s%s", invalidParametersErrorMessage, " options.link is required!" );
				}
				
				// Grab the link-specific share content
				NSString *contentDescription = nil;
				NSString *contentTitle = nil;
				NSURL *imageUrl = nil;
				
				if ( dict )
				{
					contentDescription = [dict objectForKey:@"description"];
					contentTitle = [dict objectForKey:@"title"];
					imageUrl = [NSURL URLWithString:[dict objectForKey:@"picture"]];
				}
				
				FBSDKShareLinkContent *content = [[[FBSDKShareLinkContent alloc] init] autorelease];
//				content.contentDescription = contentDescription;
//				content.contentTitle = contentTitle;
//				content.imageURL = imageUrl;
				content.quote = contentDescription;
				
				if ( [action isEqualToString:@"feed"] )
				{
					// Present the traditional feed dialog
					dialog.mode = FBSDKShareDialogModeFeedWeb;
				}
				
				// Attach universal ShareContent fields.
				content.contentURL = contentUrl;
				content.peopleIDs = peopleIds;
				content.placeID = placeId;
				content.ref = ref;
				
				// Hook up the content to present on this Share Dialog.
				// NOTE: This is currently undocumented in Facebook SDK v4 docs.
				// Find it in FBSDKShareDialog.m: Properties
				dialog.shareContent = content;
				
				// Present the share dialog after it has been configured with Share Content.
				[dialog show];
				
			}
			else if ( [action isEqualToString:@"photo"] )
			{
				if ( ! IsFacebookAppEnabled() )
				{
					// TODO: Just throw an error or redirect people to the store as well?
					CORONA_LOG_ERROR( "Facebook app isn't installed for sharing photos.");
					return;
				}
				// TODO: Check size of photo!
				// Grab the photo-specific share content
				NSArray *photosDataFromLua = nil;
				if ( dict )
				{
					photosDataFromLua = [[dict objectForKey:@"photos"] allValues];
				}
				
				if ( photosDataFromLua )
				{
					// Maintain an array of all SharePhoto objects that we'll use to share with Facebook.
					NSMutableArray *sharePhotosArray = [[[NSMutableArray alloc] init] autorelease];
					
					// Keep track of how many SharePhoto objects have been created asynchronously.
					__block NSUInteger photosCount = [photosDataFromLua count];
					__block NSUInteger photosProcessed = 0;
					
					// Create SharePhoto objects from all the provided photo data.
					for (NSDictionary *photoData in photosDataFromLua) {
						
						// Grab SharePhoto parameters.
						NSString *caption = [photoData objectForKey:@"caption"];
						NSURL *imageUrl = [NSURL URLWithString:[photoData objectForKey:@"url"]];
						
						// Download this image and create a UIImage for it:
						// Based on: http://stackoverflow.com/questions/7694215/create-a-uiimage-with-a-url-in-ios
						dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
							NSData *imageData = [NSData dataWithContentsOfURL:imageUrl];
							UIImage *image = [UIImage imageWithData:imageData];
							
							// Create the SharePhoto object and add it to the list.
							FBSDKSharePhoto *sharePhoto = [FBSDKSharePhoto photoWithImage:image userGenerated:false];
							sharePhoto.caption = caption;
							[sharePhotosArray addObject:sharePhoto];
							
							// Mark this photo as processed.
							photosProcessed++;
							
							// If this was the last image to download, now we can present the dialog.
							if (photosProcessed >= photosCount)
							{
								dispatch_async(dispatch_get_main_queue(), ^{
									showSharePhotoDialogWithProperties(sharePhotosArray, contentUrl, peopleIds, placeId, ref);
								});
							}
						});
					}
					
				} // else, an empty photos table was provided.
			}
		} // TODO: Investigate this note in Facebook's changelog for v4.7.0: The completion results sent to the delegate of GameRequestDialog will now contain a key "to" with a NSArray value containing the recipients.
		else if ( [action isEqualToString:@"requests"] || [action isEqualToString:@"apprequests"] )
		{
			// Grab game request-specific data
			NSString *message = nil;
			NSString *to = nil; // Is mapped to "recipients" as Facebook deprecated "to" on iOS.
			NSString *data = nil;
			NSString *title = nil;
			FBSDKGameRequestActionType actionType = FBSDKGameRequestActionTypeNone;
			NSString *objectId = nil;
			FBSDKGameRequestFilter filters = FBSDKGameRequestFilterNone;
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
	}
	else //! CORONA_VERIFY( action )
	{
		CORONA_LOG_ERROR( "%s", invalidParametersErrorMessage );
	}
}

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

