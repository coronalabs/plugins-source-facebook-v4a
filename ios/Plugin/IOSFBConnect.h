// ----------------------------------------------------------------------------
// 
// IOSFBConnect.h
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// Reviewers:
// 		Walter
//
// ----------------------------------------------------------------------------

#ifndef _IOSFBConnect_H__
#define _IOSFBConnect_H__

#include "CoronaLua.h"
#include "FBConnect.h"
#include "FBConnectEvent.h"

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <FBSDKShareKit/FBSDKShareKit.h>

// ----------------------------------------------------------------------------

@class NSArray;
@class NSError;
@class NSString;
@class NSURL;

@protocol CoronaRuntime;

struct lua_State;

namespace Corona
{

class FBConnectEvent;

// ----------------------------------------------------------------------------

class IOSFBConnect : public FBConnect
{
	public:
		typedef FBConnect Super;
		typedef IOSFBConnect Self;

	public:
		IOSFBConnect( id< CoronaRuntime > runtime );
		virtual ~IOSFBConnect();

	protected:
		bool Initialize( NSString *appId );

	protected:
		void LoginStateChanged( FBConnectLoginEvent::Phase state, NSError *error ) const;
		void ReauthorizationCompleted( NSError *error ) const;

	public:
		void Dispatch( const FBConnectEvent& e ) const;

	public:
		virtual int GetCurrentAccessToken( lua_State *L ) const;
		virtual bool IsAccessDenied() const;
		virtual bool IsFacebookAppEnabled() const;
		virtual void Login( const char *permissions[], int numPermissions, bool attempNativeLogin ) const;
		virtual void Logout() const;
		virtual void PublishInstall() const;
		virtual void Request( lua_State *L, const char *path, const char *httpMethod, int x ) const;
		virtual void ShowDialog( lua_State *L, int index ) const;
		virtual void DispatchInit( lua_State *L ) const;
		virtual int GetSDKVersion( lua_State *L ) const;

	protected:
		void LoginAppropriately( NSArray *permissions ) const;
		void LoginWithOnlyRequiredPermissions() const;
		void RequestPermissions( NSArray *permissions ) const;
		void HandleRequestPermissionsResponse( FBSDKLoginManagerLoginResult *result, NSError *error ) const;

	private:
		static int CreateLuaTableFromStringArray( lua_State *L, NSArray* array );
		static bool IsShareAction( NSString *action );
		virtual FBSDKShareDialog *newShareDialogWithCoronaConfiguration() const;
		virtual void showSharePhotoDialogWithProperties( NSMutableArray* sharePhotosArray, NSURL *contentUrl,
													 NSArray *peopleIds, NSString *placeId, NSString *ref ) const;
		static FBSDKGameRequestActionType GetActionTypeFrom( NSString* actionTypeString );
		static FBSDKGameRequestFilter GetFilterFrom( NSString* filterString );
	
	private:
		id< CoronaRuntime > fRuntime;
		id fConnectionDelegate;
		id fNoAppIdAlertDelegate;
		id fShareDialogDelegate;
		id fGameRequestDialogDelegate;
		mutable bool fHasObserver;
	
		// Facebook account management
		FBSDKLoginManager *fLoginManager;
		NSString *fFacebookAppId;
	
		// Error messages
		static const char kLostAccessTokenError[];
	
		// Enum to NSString conversion dictionaries
		static NSDictionary* FBSDKGameRequestActionTypeDictionary;
		static NSDictionary* FBSDKGameRequestFilterDictionary;
};

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

#endif // _IOSFBConnect_H__
